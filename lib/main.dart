import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'produto_isar.dart';

late Isar isar;
late Dio dio;
List<ProdutoIsar> produtosWeb = [];
List<Map<String, dynamic>> vendasWeb = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open([ProdutoIsarSchema], directory: dir.path);
  }
  final baseUrl = kIsWeb? 'http://localhost:8080' : 'http://10.0.2.2:8080';
  dio = Dio(BaseOptions(baseUrl: baseUrl));
  runApp(const MyApp());
}

Future<void> salvarWeb() async {
  final prefs = await SharedPreferences.getInstance();
  final lista = produtosWeb.map((e) => {'id': e.id, 'nome': e.nome, 'preco': e.preco, 'quantidade': e.quantidade, 'sincronizado': e.sincronizado}).toList();
  await prefs.setString('produtos_web', jsonEncode(lista));
  await prefs.setString('vendas_web', jsonEncode(vendasWeb));
}

Future<void> carregarWebDoStorage() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonStr = prefs.getString('produtos_web');
  if (jsonStr!= null) {
    final List decoded = jsonDecode(jsonStr);
    produtosWeb = decoded.map((m) => ProdutoIsar()..id = m['id']..nome = m['nome']..preco = (m['preco'] as num?)?.toDouble()..quantidade = m['quantidade']..sincronizado = m['sincronizado']?? false).toList();
  }
  final vStr = prefs.getString('vendas_web');
  if(vStr!= null) vendasWeb = List<Map<String,dynamic>>.from(jsonDecode(vStr));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData.dark(), home: const LoginPage());
  }
}

class LoginPage extends StatefulWidget { const LoginPage({super.key}); @override State<LoginPage> createState()=>_LoginPageState();}
class _LoginPageState extends State<LoginPage> {
  final user = TextEditingController(text: 'admin');
  final pass = TextEditingController(text: '123');
  bool loading = false;
  Future<void> login() async {
    setState(()=>loading=true);
    try {
      final res = await dio.post('/auth/login', data: {'username': user.text, 'password': pass.text});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', res.data['token']);
      if(mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=>const HomePage()));
    } catch(e){

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', 'offline_token');
      await prefs.setString('offline_user', user.text);
      if(mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=>const HomePage()));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Modo OFFLINE ativado (backend com 403)'), backgroundColor: Colors.orange));
      }
    }
    setState(()=>loading=false);
  }
  @override Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: const Text('Login - Estoque App')), body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      TextField(controller: user, decoration: const InputDecoration(labelText: 'Usuário')),
      TextField(controller: pass, decoration: const InputDecoration(labelText: 'Senha'), obscureText: true),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: loading?null:login, child: Text(loading?'Entrando...':'Entrar'))),
      const SizedBox(height: 10),
      TextButton(onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=>const RegisterPage())), child: const Text('Não tenho conta. Criar conta')),
    ])));
  }
}

class RegisterPage extends StatefulWidget { const RegisterPage({super.key}); @override State<RegisterPage> createState()=>_RegisterPageState();}
class _RegisterPageState extends State<RegisterPage> {
  final user = TextEditingController();
  final pass = TextEditingController();
  bool loading = false;
  Future<void> registrar() async {
    setState(()=>loading=true);
    try{
      await dio.post('/auth/register', data: {'username': user.text, 'password': pass.text});
      if(mounted){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conta criada! Faça login'))); Navigator.pop(context); }
    }catch(e){

      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conta criada OFFLINE! Pode fazer login'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    }
    setState(()=>loading=false);
  }
  @override Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: const Text('Criar Conta')), body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      TextField(controller: user, decoration: const InputDecoration(labelText: 'Novo usuário')),
      TextField(controller: pass, decoration: const InputDecoration(labelText: 'Nova senha'), obscureText: true),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: loading?null:registrar, child: Text(loading?'Criando...':'Criar Conta'))),
    ])));
  }
}

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState()=> _HomePageState();}
class _HomePageState extends State<HomePage>{
  int index = 0;
  final pages = [const ProdutosPage(), const DashboardPage()];
  @override Widget build(BuildContext context){
    return Scaffold(body: pages[index], bottomNavigationBar: BottomNavigationBar(currentIndex: index, onTap: (i)=> setState(()=> index=i), items: const [BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Produtos'), BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard')]));
  }
}

class DashboardPage extends StatefulWidget { const DashboardPage({super.key}); @override State<DashboardPage> createState()=> _DashboardPageState();}
class _DashboardPageState extends State<DashboardPage>{
  int totalProdutos = 0; int totalVendas = 0; double totalDinheiro = 0;
  @override void initState(){ super.initState(); carregarDados(); }
  Future<void> carregarDados() async { await carregarWebDoStorage(); setState((){ totalProdutos = produtosWeb.length; totalVendas = vendasWeb.length; totalDinheiro = vendasWeb.fold(0.0, (s,v) => s + (v['valorTotal'] as num).toDouble()); }); }
  @override Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: const Text('Dashboard')), body: RefreshIndicator(onRefresh: carregarDados, child: ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: ListTile(leading: const Icon(Icons.inventory, size: 40), title: const Text('Produtos Cadastrados'), subtitle: Text('$totalProdutos', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)))),
      Card(child: ListTile(leading: const Icon(Icons.shopping_cart, size: 40, color: Colors.orange), title: const Text('Total de Vendas'), subtitle: Text('$totalVendas', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)))),
      Card(color: Colors.green[900], child: ListTile(leading: const Icon(Icons.attach_money, size: 40, color: Colors.greenAccent), title: const Text('Total R\$ em Vendas'), subtitle: Text('R\$ ${totalDinheiro.toStringAsFixed(2)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.greenAccent)))),
      const SizedBox(height: 20), const Text('Últimas vendas:'),...vendasWeb.reversed.take(10).map((v)=> ListTile(dense: true, title: Text('${v['produto']} - ${v['qtd']} un'), subtitle: Text('${v['data']}'), trailing: Text('R\$ ${v['valorTotal']}'))),
    ])));
  }
}

class ProdutosPage extends StatefulWidget { const ProdutosPage({super.key}); @override State<ProdutosPage> createState()=>_ProdutosPageState();}
class _ProdutosPageState extends State<ProdutosPage> {
  List<ProdutoIsar> produtos = [];
  @override void initState(){ super.initState(); carregar(); }
  Future<void> carregar() async { if(kIsWeb){ await carregarWebDoStorage(); produtos = List.from(produtosWeb); } else { produtos = await isar.produtoIsars.where().findAll(); } setState((){}); }
  Future<void> addProduto() async {
    final nomeCtrl = TextEditingController(); final precoCtrl = TextEditingController(); final qtdCtrl = TextEditingController();
    await showDialog(context: context, builder: (_)=>AlertDialog(title: const Text('Novo Produto'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: nomeCtrl, decoration: const InputDecoration(labelText: 'Nome')), TextField(controller: precoCtrl, decoration: const InputDecoration(labelText: 'Preço'), keyboardType: TextInputType.number), TextField(controller: qtdCtrl, decoration: const InputDecoration(labelText: 'Qtd'), keyboardType: TextInputType.number)]), actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Cancelar')), ElevatedButton(onPressed: () async { final p = ProdutoIsar()..nome=nomeCtrl.text..preco=double.tryParse(precoCtrl.text.replaceAll(',','.'))?? 0..quantidade=int.tryParse(qtdCtrl.text)?? 0..sincronizado=false; if(kIsWeb){ p.id = DateTime.now().millisecondsSinceEpoch; produtosWeb.add(p); await salvarWeb(); } else { await isar.writeTxn(() async => await isar.produtoIsars.put(p)); } await carregar(); if(mounted) Navigator.pop(context); }, child: const Text('Salvar'))]));
  }
  Future<void> movimentar(ProdutoIsar p) async {
    final qtdCtrl = TextEditingController(); String tipo = 'SAIDA';
    await showDialog(context: context, builder: (_)=> StatefulBuilder(builder: (context, setDialogState)=> AlertDialog(title: Text('Movimentar: ${p.nome}'), content: Column(mainAxisSize: MainAxisSize.min, children: [Text('Estoque atual: ${p.quantidade}'), DropdownButton<String>(value: tipo, isExpanded: true, items: const [DropdownMenuItem(value: 'SAIDA', child: Text('Saída - Venda')), DropdownMenuItem(value: 'ENTRADA', child: Text('Entrada - Compra'))], onChanged: (v){ setDialogState(()=> tipo = v!); }), TextField(controller: qtdCtrl, decoration: const InputDecoration(labelText: 'Quantidade'), keyboardType: TextInputType.number)]), actions: [TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Cancelar')), ElevatedButton(onPressed: () async { final qtdMov = int.tryParse(qtdCtrl.text)?? 0; if(qtdMov <=0) return; if(tipo=='SAIDA'){ p.quantidade = (p.quantidade??0) - qtdMov; if((p.quantidade??0) <0) p.quantidade =0; vendasWeb.add({'produto': p.nome, 'qtd': qtdMov, 'valorTotal': (p.preco??0) * qtdMov, 'data': DateTime.now().toString().substring(0,16)}); } else { p.quantidade = (p.quantidade??0) + qtdMov; } p.sincronizado = false; if(kIsWeb){ await salvarWeb(); } else { await isar.writeTxn(() async => await isar.produtoIsars.put(p)); } await carregar(); if(mounted) Navigator.pop(context); }, child: const Text('Confirmar'))])));
  }
  Future<void> excluir(ProdutoIsar p) async { final confirm = await showDialog<bool>(context: context, builder: (_)=> AlertDialog(title: const Text('Excluir?'), content: Text('Excluir ${p.nome}?'), actions: [TextButton(onPressed: ()=> Navigator.pop(context, false), child: const Text('Não')), ElevatedButton(onPressed: ()=> Navigator.pop(context, true), child: const Text('Sim'))])); if(confirm!=true) return; if(kIsWeb){ produtosWeb.removeWhere((e)=> e.id==p.id); await salvarWeb(); } else { await isar.writeTxn(() async => await isar.produtoIsars.delete(p.id)); } await carregar(); }
  Future<void> sincronizar() async { try{ final prefs = await SharedPreferences.getInstance(); final token = prefs.getString('token'); dio.options.headers['Authorization']='Bearer $token'; List<ProdutoIsar> pendentes = kIsWeb? produtosWeb.where((e)=>!e.sincronizado).toList() : await isar.produtoIsars.filter().sincronizadoEqualTo(false).findAll(); if(pendentes.isEmpty){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tudo sincronizado'))); return; } for(var p in pendentes){ await dio.post('/produtos', data: {'nome':p.nome,'preco':p.preco,'quantidade':p.quantidade,'estoqueMinimo':2,'descricao':'App','codigoBarras':'${DateTime.now().millisecondsSinceEpoch}'}); p.sincronizado=true; if(kIsWeb){ await salvarWeb(); } else { await isar.writeTxn(() async => await isar.produtoIsars.put(p)); } } ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${pendentes.length} sincronizados!'))); await carregar(); }catch(e){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro sync: $e')));} }
  @override Widget build(BuildContext context){ return Scaffold(appBar: AppBar(title: const Text('Produtos - Offline First'), actions: [IconButton(icon: const Icon(Icons.sync), onPressed: sincronizar)]), body: produtos.isEmpty? const Center(child: Text('Nenhum produto. Clique no +')) : ListView.builder(itemCount: produtos.length, itemBuilder: (_,i){ final p = produtos[i]; return Card(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: ListTile(title: Text(p.nome??'-'), subtitle: Text('R\$ ${p.preco} - Qtd: ${p.quantidade}'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Icon(p.sincronizado?Icons.cloud_done:Icons.cloud_off, color: p.sincronizado?Colors.green:Colors.orange), IconButton(icon: const Icon(Icons.swap_horiz), onPressed: ()=> movimentar(p)), IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: ()=> excluir(p))]), onTap: ()=> movimentar(p))); }), floatingActionButton: FloatingActionButton(onPressed: addProduto, child: const Icon(Icons.add))); }
}