import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'modelos.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://slkvdxuatmcevbpnvxuk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNsa3ZkeHVhdG1jZXZicG52eHVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU5NjY5NzQsImV4cCI6MjEwMTU0Mjk3NH0.vHoVoYXE-ON_zGF8KoW0cOgRftprsR_KwewoB7qrIYo',
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MiJuegoGallinero());
}

class MiJuegoGallinero extends StatelessWidget {
  const MiJuegoGallinero({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Palenque de Pelea Online',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        primaryColor: Colors.amber,
      ),
      home: const PantallaLobby(),
    );
  }
}

class PantallaLobby extends StatefulWidget {
  const PantallaLobby({super.key});

  @override
  State<PantallaLobby> createState() => _PantallaLobbyState();
}

class _PantallaLobbyState extends State<PantallaLobby> with WidgetsBindingObserver {
  int indicePestana = 0;
  int monedas = 500;
  int diamantes = 10;
  int nivelHistoriaMaximo = 1;
  String miCodigoAmigo = '';
  String nombreUsuario = '';
  bool cuentaVinculada = false;
  String emailVinculado = '';

  int nivelPerfil = 1;
  int xpPerfil = 0;
  int xpSiguienteNivel = 100;

  List<Gallo> misGallos = [];
  List<Gallina> misGallinas = [];
  List<HuevoCriadero> huevosCriadero = [];
  List<String> amigosAgregados = [];
  List<int> nivelesPaseReclamados = [];
  List<SolicitudPelea> peleasPendientes = [];
  List<SolicitudIntercambio> intercambiosPendientes = [];

  TextEditingController controllerIDAmigo = TextEditingController();

  Gallo? galloPelea1, galloPelea2;
  Gallo? galloCruce;
  Gallina? gallinaCruce;

  RealtimeChannel? canalPeleasSupabase;
  RealtimeChannel? canalIntercambiosSupabase;
  bool enCombateActivo = false;
  String ultimoIntercambioRechazadoID = '';

  Timer? _tickerUI;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarDatosGuardados();
    _tickerUI = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (canalPeleasSupabase != null) Supabase.instance.client.removeChannel(canalPeleasSupabase!);
    if (canalIntercambiosSupabase != null) Supabase.instance.client.removeChannel(canalIntercambiosSupabase!);
    controllerIDAmigo.dispose();
    _tickerUI?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _iniciarEscuchaBuzonesSupabase();
    }
  }

  Future<void> _cargarDatosGuardados() async {
    final prefs = await SharedPreferences.getInstance();

    String? idGuardado = prefs.getString('miCodigoAmigo');
    if (idGuardado == null) {
      idGuardado = (1000 + Random().nextInt(9000)).toString();
      await prefs.setString('miCodigoAmigo', idGuardado);
    }

    setState(() {
      miCodigoAmigo = idGuardado!;
      monedas = prefs.getInt('monedas') ?? 500;
      diamantes = prefs.getInt('diamantes') ?? 10;
      nivelHistoriaMaximo = prefs.getInt('nivelHistoria') ?? 1;
      nombreUsuario = prefs.getString('nombreUsuario') ?? '';
      cuentaVinculada = prefs.getBool('cuentaVinculada') ?? false;
      emailVinculado = prefs.getString('emailVinculado') ?? '';

      nivelPerfil = prefs.getInt('nivelPerfil') ?? 1;
      xpPerfil = prefs.getInt('xpPerfil') ?? 0;
      xpSiguienteNivel = nivelPerfil * 100;

      amigosAgregados = prefs.getStringList('amigosAgregados') ?? [];

      List<String>? reclamadosStr = prefs.getStringList('nivelesPaseReclamados');
      if (reclamadosStr != null) {
        nivelesPaseReclamados = reclamadosStr.map((e) => int.parse(e)).toList();
      }

      String? gallosJson = prefs.getString('misGallos');
      if (gallosJson != null) {
        Iterable l = jsonDecode(gallosJson);
        misGallos = List<Gallo>.from(l.map((model) => Gallo.fromJson(model)));
      }

      String? gallinasJson = prefs.getString('misGallinas');
      if (gallinasJson != null) {
        Iterable l = jsonDecode(gallinasJson);
        misGallinas = List<Gallina>.from(l.map((model) => Gallina.fromJson(model)));
      } else {
        misGallinas = [Gallina.generarAleatoria(nombrePersonalizado: 'Gallina Sevillana', rareza: Rareza.sevillano)];
      }

      String? huevosJson = prefs.getString('huevosCriadero');
      if (huevosJson != null) {
        Iterable l = jsonDecode(huevosJson);
        huevosCriadero = List<HuevoCriadero>.from(l.map((model) => HuevoCriadero.fromJson(model)));
      }
    });

    _iniciarEscuchaBuzonesSupabase();

    if (emailVinculado.trim().toLowerCase() == 'adonayvargasfernandez11@gmail.com') {
      if (monedas < 1000000 || diamantes < 1000000 || nivelPerfil < 1000) {
        setState(() {
          monedas = 1000000;
          diamantes = 1000000;
          nivelPerfil = 1000;
          xpSiguienteNivel = nivelPerfil * 100;
          xpPerfil = 0;
          _guardarDatos();
        });
      }
    }

    if (nombreUsuario.isEmpty || misGallos.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pedirDatosIniciales();
      });
    }
  }

  void _iniciarEscuchaBuzonesSupabase() {
    if (miCodigoAmigo.isEmpty) return;

    if (canalPeleasSupabase != null) Supabase.instance.client.removeChannel(canalPeleasSupabase!);
    if (canalIntercambiosSupabase != null) Supabase.instance.client.removeChannel(canalIntercambiosSupabase!);

    canalPeleasSupabase = Supabase.instance.client
        .channel('canal-peleas-$miCodigoAmigo')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'buzones',
          callback: (payload) async {
            final response = await Supabase.instance.client
                .from('buzones')
                .select()
                .eq('id', miCodigoAmigo)
                .maybeSingle();

            if (response != null) {
              String rawDatos = response['datos'] ?? '';
              if (rawDatos.isNotEmpty) {
                Map<String, dynamic> mapa = jsonDecode(rawDatos);
                String tipo = mapa['tipo'] ?? '';

                if (tipo == 'pelea') {
                  await _limpiarBuzonNube();

                  setState(() {
                    bool existe = peleasPendientes.any((p) => p.combateID == mapa['combateID']);
                    if (!existe) {
                      peleasPendientes.add(SolicitudPelea(
                        idRetador: mapa['idRetador'],
                        nombreRetador: mapa['nombreRetador'],
                        apuesta: mapa['apuesta'],
                        galloRetador: Gallo.fromJson(mapa['galloRetador']),
                        combateID: mapa['combateID'] ?? 12345,
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('⚔️ ¡Nuevo reto de pelea recibido!')),
                      );
                    }
                  });
                } else if (tipo == 'iniciar_combate_online') {
                  await _limpiarBuzonNube();

                  if (enCombateActivo) return;
                  enCombateActivo = true;

                  int combID = mapa['combateID'];
                  Gallo galloRivalAceptado = Gallo.fromJson(mapa['galloAceptado']);
                  int ap = mapa['apuesta'] ?? 0;

                  Gallo miGalloEnviado = misGallos.first;
                  for (var g in misGallos) {
                    if (g.id == mapa['miGalloID']) {
                      miGalloEnviado = g;
                      break;
                    }
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PantallaPeleaRealista(
                        galloJugador: miGalloEnviado,
                        galloRival: galloRivalAceptado,
                        esBoss: false,
                        nivelActual: 0,
                        apuestaMonedas: ap,
                        semillaCombate: combID,
                        onResultadoApuesta: (ganado) {
                          setState(() {
                            if (ganado) {
                              monedas += ap;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🎉 ¡VICTORIA! +🪙 $ap')));
                            } else {
                              monedas = max(0, monedas - ap);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('💀 DERROTA... -🪙 $ap')));
                            }
                            _guardarDatos();
                            enCombateActivo = false;
                          });
                        },
                        onGanaXP: () => _agregarXP(40),
                      ),
                    ),
                  ).then((_) => enCombateActivo = false);
                }
              }
            }
          },
        )
        .subscribe();

    canalIntercambiosSupabase = Supabase.instance.client
        .channel('canal-intercambios-$miCodigoAmigo')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'buzones',
          callback: (payload) async {
            final response = await Supabase.instance.client
                .from('buzones')
                .select()
                .eq('id', miCodigoAmigo)
                .maybeSingle();

            if (response != null) {
              String rawDatos = response['datos'] ?? '';
              if (rawDatos.isNotEmpty) {
                Map<String, dynamic> mapa = jsonDecode(rawDatos);
                String tipo = mapa['tipo'] ?? '';

                if (tipo == 'intercambio') {
                  await _limpiarBuzonNube();

                  setState(() {
                    String nombreRemitente = mapa['nombreRemitente'] ?? 'Amigo';
                    Gallo? gOfrecido = mapa['galloOfrecido'] != null ? Gallo.fromJson(mapa['galloOfrecido']) : null;
                    Gallina? gaOfrecida = mapa['gallinaOfrecida'] != null ? Gallina.fromJson(mapa['gallinaOfrecida']) : null;
                    int monOfrecidas = mapa['monedasOfrecidas'] ?? 0;
                    String intercambioID = mapa['intercambioID'] ?? '0';

                    bool existe = intercambiosPendientes.any((it) => it.intercambioID == intercambioID);
                    if (!existe) {
                      intercambiosPendientes.add(SolicitudIntercambio(
                        idRemitente: mapa['idRemitente'],
                        nombreRemitente: nombreRemitente,
                        galloOfrecido: gOfrecido,
                        gallinaOfrecida: gaOfrecida,
                        monedasOfrecidas: monOfrecidas,
                        intercambioID: intercambioID,
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('🤝 ¡Solicitud de intercambio recibida!')),
                      );
                    }
                  });
                } else if (tipo == 'rechazar_intercambio') {
                  await _limpiarBuzonNube();

                  String rechazoID = mapa['rechazoID'] ?? '';
                  if (rechazoID.isNotEmpty && ultimoIntercambioRechazadoID == rechazoID) {
                    return;
                  }
                  ultimoIntercambioRechazadoID = rechazoID;

                  setState(() {
                    if (mapa['galloDevuelto'] != null) {
                      misGallos.add(Gallo.fromJson(mapa['galloDevuelto']));
                    }
                    if (mapa['gallinaDevuelta'] != null) {
                      misGallinas.add(Gallina.fromJson(mapa['gallinaDevuelta']));
                    }
                    monedas += (mapa['monedasDevueltas'] as num).toInt();
                    _guardarDatos();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('⚠️ Tu oferta de intercambio fue rechazada. Objetos devueltos.')),
                    );
                  });
                }
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> _enviarSolicitudPeleaSupabase(String idDestino, SolicitudPelea solicitud) async {
    try {
      Map<String, dynamic> payload = {
        'tipo': 'pelea',
        'idRetador': solicitud.idRetador,
        'nombreRetador': solicitud.nombreRetador,
        'apuesta': solicitud.apuesta,
        'galloRetador': solicitud.galloRetador.toJson(),
        'combateID': solicitud.combateID,
      };

      await Supabase.instance.client.from('buzones').upsert({
        'id': idDestino,
        'datos': jsonEncode(payload),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('¡Reto enviado con éxito al ID $idDestino!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar reto: $e')),
      );
    }
  }

  Future<void> _enviarInicioCombateSupabase(String idDestino, Map<String, dynamic> payload) async {
    await Supabase.instance.client.from('buzones').upsert({
      'id': idDestino,
      'datos': jsonEncode(payload),
    });
  }

  Future<void> _enviarSolicitudIntercambioSupabase(String idDestino, SolicitudIntercambio solicitud) async {
    try {
      Map<String, dynamic> payload = {
        'tipo': 'intercambio',
        'idRemitente': solicitud.idRemitente,
        'nombreRemitente': solicitud.nombreRemitente,
        'galloOfrecido': solicitud.galloOfrecido?.toJson(),
        'gallinaOfrecida': solicitud.gallinaOfrecida?.toJson(),
        'monedasOfrecidas': solicitud.monedasOfrecidas,
        'intercambioID': solicitud.intercambioID,
      };

      await Supabase.instance.client.from('buzones').upsert({
        'id': idDestino,
        'datos': jsonEncode(payload),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('¡Intercambio enviado con éxito al ID $idDestino!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar intercambio: $e')),
      );
    }
  }

  Future<void> _enviarRechazoIntercambioSupabase(String idDestino, Map<String, dynamic> payload) async {
    await Supabase.instance.client.from('buzones').upsert({
      'id': idDestino,
      'datos': jsonEncode(payload),
    });
  }

  Future<void> _limpiarBuzonNube() async {
    try {
      await Supabase.instance.client.from('buzones').upsert({
        'id': miCodigoAmigo,
        'datos': '',
      });
    } catch (e) {
      // Ignorar
    }
  }

  void _pedirDatosIniciales() {
    TextEditingController controllerUsuario = TextEditingController();
    TextEditingController controllerGallo = TextEditingController();

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: const Text('¡Bienvenido al Palenque!'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Escribe tu Nombre de Usuario:'),
                const SizedBox(height: 6),
                TextField(
                  controller: controllerUsuario,
                  decoration: const InputDecoration(hintText: 'Tu nombre...', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                const Text('Escribe el nombre de tu Gallo Inicial Sevillano:'),
                const SizedBox(height: 6),
                TextField(
                  controller: controllerGallo,
                  decoration: const InputDecoration(hintText: 'Nombre de tu gallo...', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
              onPressed: () {
                String nUsuario = controllerUsuario.text.trim().isNotEmpty ? controllerUsuario.text.trim() : 'Jugador';
                String nGallo = controllerGallo.text.trim().isNotEmpty ? controllerGallo.text.trim() : 'Sevillano Inicial';

                setState(() {
                  nombreUsuario = nUsuario;
                  if (misGallos.isEmpty) {
                    misGallos.add(Gallo.generarAleatorio(nombrePersonalizado: nGallo, rareza: Rareza.sevillano));
                  }
                  _guardarDatos();
                });
                Navigator.pop(context);
              },
              child: const Text('Comenzar'),
            )
          ],
        );
      },
    );
  }

  void _agregarXP(int cantidad) {
    setState(() {
      xpPerfil += cantidad;
      if (xpPerfil >= xpSiguienteNivel) {
        xpPerfil -= xpSiguienteNivel;
        nivelPerfil++;
        xpSiguienteNivel = nivelPerfil * 100;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🎉 ¡Felicidades! Has subido al Nivel $nivelPerfil de Perfil')),
        );
      }
      _guardarDatos();
    });
  }

  Future<void> _guardarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('monedas', monedas);
    await prefs.setInt('diamantes', diamantes);
    await prefs.setInt('nivelHistoria', nivelHistoriaMaximo);
    await prefs.setString('nombreUsuario', nombreUsuario);
    await prefs.setBool('cuentaVinculada', cuentaVinculada);
    await prefs.setString('emailVinculado', emailVinculado);
    await prefs.setInt('nivelPerfil', nivelPerfil);
    await prefs.setInt('xpPerfil', xpPerfil);
    await prefs.setStringList('amigosAgregados', amigosAgregados);
    await prefs.setStringList('nivelesPaseReclamados', nivelesPaseReclamados.map((e) => e.toString()).toList());
    await prefs.setString('misGallos', jsonEncode(misGallos.map((g) => g.toJson()).toList()));
    await prefs.setString('misGallinas', jsonEncode(misGallinas.map((g) => g.toJson()).toList()));
    await prefs.setString('huevosCriadero', jsonEncode(huevosCriadero.map((h) => h.toJson()).toList()));
  }

  Future<void> _borrarTodosLosDatos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
      misGallos.clear();
      misGallinas.clear();
      huevosCriadero.clear();
      amigosAgregados.clear();
      peleasPendientes.clear();
      intercambiosPendientes.clear();
      nivelesPaseReclamados.clear();
      monedas = 500;
      diamantes = 10;
      nivelHistoriaMaximo = 1;
      nombreUsuario = '';
      cuentaVinculada = false;
      emailVinculado = '';
      nivelPerfil = 1;
      xpPerfil = 0;
      xpSiguienteNivel = 100;
    });
    _cargarDatosGuardados();
  }

  void _dialogoNombrarRecompensaPase(dynamic ave) {
    TextEditingController nombreCtrl = TextEditingController();
    bool esGallo = ave is Gallo;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: Text(esGallo ? '🐓 ¡Bautiza a tu nuevo Gallo!' : '🐔 ¡Bautiza a tu nueva Gallina!'),
          content: TextField(
            controller: nombreCtrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Escribe el nombre...', border: OutlineInputBorder()),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
              onPressed: () {
                String n = nombreCtrl.text.trim();
                setState(() {
                  if (esGallo) {
                    (ave as Gallo).nombre = n.isNotEmpty ? n : 'Gallo Pase';
                    misGallos.add(ave);
                  } else {
                    (ave as Gallina).nombre = n.isNotEmpty ? n : 'Gallina Pase';
                    misGallinas.add(ave);
                  }
                  _guardarDatos();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(esGallo ? '¡Gallo guardado en tu gallinero!' : '¡Gallina guardada en tu gallinero!')),
                );
              },
              child: const Text('Guardar'),
            )
          ],
        );
      },
    );
  }

  void _abrirPaseBatalla() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF222222),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('⚔️ Pase de Batalla (Tu Nivel: $nivelPerfil)'),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              content: SizedBox(
                width: 500,
                height: 400,
                child: ListView.builder(
                  itemCount: 1000,
                  itemBuilder: (context, index) {
                    int nivelPase = index + 1;
                    bool desbloqueado = nivelPerfil >= nivelPase;
                    bool reclamado = nivelesPaseReclamados.contains(nivelPase);

                    String tipoRecompensa = '🪙 +200 Monedas';
                    if (nivelPase % 20 == 0) {
                      tipoRecompensa = '🎁 Caja Misteriosa (Ave)';
                    } else if (nivelPase % 10 == 0) {
                      tipoRecompensa = '💎 +10 Diamantes';
                    }

                    return Card(
                      color: desbloqueado ? Colors.black87 : Colors.grey[900],
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: desbloqueado ? Colors.amber : Colors.grey,
                          child: Text('$nivelPase', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        title: Text('Nivel $nivelPase de Pase', style: TextStyle(fontWeight: FontWeight.bold, color: desbloqueado ? Colors.white : Colors.grey)),
                        subtitle: Text('Recompensa: $tipoRecompensa', style: TextStyle(color: desbloqueado ? Colors.amberAccent : Colors.grey)),
                        trailing: reclamado
                            ? const Text('Reclamado', style: TextStyle(color: Colors.green, fontSize: 11))
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: desbloqueado ? Colors.green : Colors.grey),
                                onPressed: (desbloqueado && !reclamado)
                                    ? () {
                                        Navigator.pop(context);
                                        setState(() {
                                          nivelesPaseReclamados.add(nivelPase);
                                          if (nivelPase % 20 == 0) {
                                            Random r = Random();
                                            int chance = r.nextInt(100);
                                            Rareza rarezaGanada;
                                            if (chance < 50) {
                                              rarezaGanada = Rareza.sevillano;
                                            } else if (chance < 80) {
                                              rarezaGanada = Rareza.ingles;
                                            } else if (chance < 93) {
                                              rarezaGanada = Rareza.shamo;
                                            } else if (chance < 98) {
                                              rarezaGanada = Rareza.minino;
                                            } else {
                                              rarezaGanada = Rareza.calcuta;
                                            }

                                            if (r.nextBool()) {
                                              Gallo nuevoG = Gallo.generarAleatorio(nombrePersonalizado: 'Caja', rareza: rarezaGanada);
                                              _dialogoNombrarRecompensaPase(nuevoG);
                                            } else {
                                              Gallina nuevaGa = Gallina.generarAleatoria(nombrePersonalizado: 'Caja', rareza: rarezaGanada);
                                              _dialogoNombrarRecompensaPase(nuevaGa);
                                            }
                                          } else if (nivelPase % 10 == 0) {
                                            diamantes += 10;
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('💎 ¡Has reclamado +10 Diamantes!')));
                                          } else {
                                            monedas += 200;
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🪙 ¡Has reclamado +200 Monedas!')));
                                          }
                                          _guardarDatos();
                                        });
                                      }
                                    : null,
                                child: const Text('Reclamar', style: TextStyle(fontSize: 10)),
                              ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _abrirPerfil() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2C2C2C),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('👤 Perfil: $nombreUsuario'),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.star, color: Colors.cyanAccent),
                      title: Text('Nivel $nivelPerfil'),
                      subtitle: Text('XP: $xpPerfil / $xpSiguienteNivel (Faltan ${xpSiguienteNivel - xpPerfil} XP)'),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.edit, color: Colors.amber),
                      title: const Text('Cambiar Nombre de Usuario'),
                      subtitle: const Text('Coste: 🪙 100 Monedas', style: TextStyle(color: Colors.amberAccent, fontSize: 11)),
                      onTap: () {
                        if (monedas < 100) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Necesitas 100 monedas para cambiar de nombre')));
                          return;
                        }
                        TextEditingController nuevoNombreCtrl = TextEditingController(text: nombreUsuario);
                        showDialog(
                          context: context,
                          builder: (c) => AlertDialog(
                            backgroundColor: const Color(0xFF3A3A3A),
                            title: const Text('Nuevo Nombre'),
                            content: TextField(
                              controller: nuevoNombreCtrl,
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
                                onPressed: () {
                                  if (nuevoNombreCtrl.text.trim().isNotEmpty) {
                                    setState(() {
                                      monedas -= 100;
                                      nombreUsuario = nuevoNombreCtrl.text.trim();
                                      _guardarDatos();
                                    });
                                    setDialogState(() {});
                                    Navigator.pop(c);
                                  }
                                },
                                child: const Text('Cambiar'),
                              )
                            ],
                          ),
                        );
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: Icon(cuentaVinculada ? Icons.check_circle : Icons.link_off, color: cuentaVinculada ? Colors.green : Colors.redAccent),
                      title: Text(cuentaVinculada ? 'Cuenta Vinculada' : 'Vincular Cuenta'),
                      subtitle: Text(cuentaVinculada ? 'Email: $emailVinculado' : 'Guarda tu progreso para no perderlo al cambiar de móvil', style: const TextStyle(fontSize: 11)),
                      onTap: cuentaVinculada
                          ? null
                          : () {
                              TextEditingController emailCtrl = TextEditingController();
                              TextEditingController passCtrl = TextEditingController();
                              showDialog(
                                context: context,
                                builder: (c) => AlertDialog(
                                  backgroundColor: const Color(0xFF3A3A3A),
                                  title: const Text('Vincular Cuenta'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextField(
                                        controller: emailCtrl,
                                        keyboardType: TextInputType.emailAddress,
                                        decoration: const InputDecoration(hintText: 'Correo electrónico', border: OutlineInputBorder()),
                                      ),
                                      const SizedBox(height: 10),
                                      TextField(
                                        controller: passCtrl,
                                        obscureText: true,
                                        decoration: const InputDecoration(hintText: 'Contraseña', border: OutlineInputBorder()),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                      onPressed: () {
                                        String mail = emailCtrl.text.trim().toLowerCase();
                                        String pass = passCtrl.text.trim();

                                        if (mail.isNotEmpty && pass.isNotEmpty) {
                                          setState(() {
                                            cuentaVinculada = true;
                                            emailVinculado = mail;
                                            if (mail == 'adonayvargasfernandez11@gmail.com' && pass == '13245678') {
                                              monedas = 1000000;
                                              diamantes = 1000000;
                                              nivelPerfil = 1000;
                                              xpSiguienteNivel = nivelPerfil * 100;
                                              xpPerfil = 0;
                                            }
                                            _guardarDatos();
                                          });
                                          setDialogState(() {});
                                          Navigator.pop(c);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(mail == 'adonayvargasfernandez11@gmail.com' ? '¡Cuenta de fábrica vinculada! +1M Monedas, +1M Diamantes y Nivel 1000 XP.' : '¡Cuenta vinculada correctamente!')),
                                          );
                                        }
                                      },
                                      child: const Text('Vincular'),
                                    )
                                  ],
                                ),
                              );
                            },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                      title: const Text('Borrar Todos los Datos', style: TextStyle(color: Colors.redAccent)),
                      subtitle: const Text('Reinicia el juego desde cero', style: TextStyle(fontSize: 11)),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (c) => AlertDialog(
                            backgroundColor: const Color(0xFF3A3A3A),
                            title: const Text('¿Borrar Datos?'),
                            content: const Text('Se reseteará todo tu progreso local.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () {
                                  Navigator.pop(c);
                                  Navigator.pop(context);
                                  _borrarTodosLosDatos();
                                },
                                child: const Text('Borrar Todo'),
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _agregarAmigo() {
    String codigo = controllerIDAmigo.text.trim();

    if (codigo.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El ID del amigo debe tener exactamente 4 cifras')));
      return;
    }

    if (codigo == miCodigoAmigo) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No puedes agregarte a ti mismo')));
      return;
    }

    if (amigosAgregados.contains(codigo)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este amigo ya está en tu lista')));
      return;
    }

    setState(() {
      amigosAgregados.add(codigo);
      controllerIDAmigo.clear();
      _guardarDatos();
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('¡Amigo con ID $codigo agregado correctamente!')));
  }

  void _dialogoRenombrarGallo(Gallo g) {
    TextEditingController ctrl = TextEditingController(text: g.nombre);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: Text('Cambiar nombre a ${g.nombre}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Coste de cambio: 🪙 50 Monedas'),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(hintText: 'Nuevo nombre...', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
              onPressed: () {
                if (monedas < 50) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tienes 50 monedas')));
                  return;
                }
                String nuevoNombre = ctrl.text.trim();
                if (nuevoNombre.isNotEmpty) {
                  setState(() {
                    monedas -= 50;
                    g.nombre = nuevoNombre;
                    _guardarDatos();
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('¡Gallo renombrado a "$nuevoNombre"!')));
                }
              },
              child: const Text('Renombrar (-🪙 50)'),
            )
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // LÓGICA DE PELEAS ONLINE ENTRE AMIGOS
  // ---------------------------------------------------------------------

  void _enviarPeticionPelea(String idAmigo) {
    if (misGallos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tienes gallos para retar a un amigo')));
      return;
    }

    Gallo galloSeleccionado = misGallos.first;
    TextEditingController apuestaCtrl = TextEditingController(text: '50');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2C2C2C),
              title: Text('Retar a $idAmigo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Elige tu gallo:'),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 150,
                      width: 350,
                      child: ListView.builder(
                        itemCount: misGallos.length,
                        itemBuilder: (context, index) {
                          Gallo g = misGallos[index];
                          bool sel = g.id == galloSeleccionado.id;
                          return ListTile(
                            tileColor: sel ? Colors.amber.withOpacity(0.2) : null,
                            leading: Icon(Icons.egg_alt, color: sel ? Colors.amber : Colors.grey),
                            title: Text(g.nombre),
                            subtitle: Text('ATK ${g.ataque} | DEF ${g.defensa}'),
                            onTap: () => setDialogState(() => galloSeleccionado = g),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: apuestaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Apuesta en monedas', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
                  onPressed: () {
                    int apuestaElegida = int.tryParse(apuestaCtrl.text.trim()) ?? 50;
                    if (apuestaElegida <= 0 || apuestaElegida > monedas) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Apuesta inválida o insuficiente')));
                      return;
                    }
                    Navigator.pop(context);

                    int combID = Random().nextInt(2000000000);
                    SolicitudPelea solicitud = SolicitudPelea(
                      idRetador: miCodigoAmigo,
                      nombreRetador: nombreUsuario,
                      apuesta: apuestaElegida,
                      galloRetador: galloSeleccionado,
                      combateID: combID,
                    );
                    _enviarSolicitudPeleaSupabase(idAmigo, solicitud);
                  },
                  child: const Text('Enviar Reto'),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _aceptarPeleaPendiente(SolicitudPelea sol) {
    if (misGallos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tienes gallos disponibles para pelear')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: Text('Elige tu gallo contra ${sol.nombreRetador}'),
          content: SizedBox(
            width: 400,
            height: 300,
            child: ListView.builder(
              itemCount: misGallos.length,
              itemBuilder: (context, index) {
                Gallo g = misGallos[index];
                return ListTile(
                  leading: const Icon(Icons.egg_alt, color: Colors.amber),
                  title: Text(g.nombre),
                  subtitle: Text('ATK ${g.ataque} | DEF ${g.defensa} | VEL ${g.velocidad}'),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmarAceptarPelea(sol, g);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ],
        );
      },
    );
  }

  void _confirmarAceptarPelea(SolicitudPelea sol, Gallo miGallo) async {
    setState(() {
      peleasPendientes.removeWhere((p) => p.combateID == sol.combateID);
    });

    Map<String, dynamic> payload = {
      'tipo': 'iniciar_combate_online',
      'combateID': sol.combateID,
      'galloAceptado': miGallo.toJson(),
      'apuesta': sol.apuesta,
      'miGalloID': sol.galloRetador.id,
    };

    try {
      await _enviarInicioCombateSupabase(sol.idRetador, payload);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al iniciar combate: $e')));
      return;
    }

    if (enCombateActivo) return;
    enCombateActivo = true;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PantallaPeleaRealista(
          galloJugador: miGallo,
          galloRival: sol.galloRetador,
          esBoss: false,
          nivelActual: 0,
          apuestaMonedas: sol.apuesta,
          semillaCombate: sol.combateID,
          onResultadoApuesta: (ganado) {
            setState(() {
              if (ganado) {
                monedas += sol.apuesta;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🎉 ¡VICTORIA! +🪙 ${sol.apuesta}')));
              } else {
                monedas = max(0, monedas - sol.apuesta);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('💀 DERROTA... -🪙 ${sol.apuesta}')));
              }
              _guardarDatos();
              enCombateActivo = false;
            });
          },
          onGanaXP: () => _agregarXP(40),
        ),
      ),
    ).then((_) => enCombateActivo = false);
  }

  void _rechazarPeleaPendiente(SolicitudPelea sol) async {
    setState(() {
      peleasPendientes.removeWhere((p) => p.combateID == sol.combateID);
    });
    await _limpiarBuzonNube();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Has rechazado el reto de ${sol.nombreRetador}')));
  }

  // ---------------------------------------------------------------------
  // LÓGICA DE INTERCAMBIOS ONLINE ENTRE AMIGOS
  // ---------------------------------------------------------------------

  void _dialogoEnviarIntercambio(String idAmigo) {
    String tipoOferta = 'monedas';
    Gallo? galloOfertado;
    Gallina? gallinaOfertada;
    TextEditingController monedasCtrl = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2C2C2C),
              title: Text('Intercambio con $idAmigo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      children: [
                        ChoiceChip(
                          label: const Text('Monedas'),
                          selected: tipoOferta == 'monedas',
                          onSelected: (v) => setDialogState(() => tipoOferta = 'monedas'),
                        ),
                        ChoiceChip(
                          label: const Text('Gallo'),
                          selected: tipoOferta == 'gallo',
                          onSelected: (v) => setDialogState(() => tipoOferta = 'gallo'),
                        ),
                        ChoiceChip(
                          label: const Text('Gallina'),
                          selected: tipoOferta == 'gallina',
                          onSelected: (v) => setDialogState(() => tipoOferta = 'gallina'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (tipoOferta == 'monedas')
                      TextField(
                        controller: monedasCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Monedas a ofrecer', border: OutlineInputBorder()),
                      ),
                    if (tipoOferta == 'gallo')
                      SizedBox(
                        height: 150,
                        width: 350,
                        child: misGallos.isEmpty
                            ? const Center(child: Text('No tienes gallos'))
                            : ListView.builder(
                                itemCount: misGallos.length,
                                itemBuilder: (context, index) {
                                  Gallo g = misGallos[index];
                                  bool sel = galloOfertado?.id == g.id;
                                  return ListTile(
                                    tileColor: sel ? Colors.amber.withOpacity(0.2) : null,
                                    title: Text(g.nombre),
                                    subtitle: Text('Rareza: ${g.rareza.name}'),
                                    onTap: () => setDialogState(() => galloOfertado = g),
                                  );
                                },
                              ),
                      ),
                    if (tipoOferta == 'gallina')
                      SizedBox(
                        height: 150,
                        width: 350,
                        child: misGallinas.isEmpty
                            ? const Center(child: Text('No tienes gallinas'))
                            : ListView.builder(
                                itemCount: misGallinas.length,
                                itemBuilder: (context, index) {
                                  Gallina g = misGallinas[index];
                                  bool sel = gallinaOfertada?.id == g.id;
                                  return ListTile(
                                    tileColor: sel ? Colors.amber.withOpacity(0.2) : null,
                                    title: Text(g.nombre),
                                    subtitle: Text('Rareza: ${g.rareza.name}'),
                                    onTap: () => setDialogState(() => gallinaOfertada = g),
                                  );
                                },
                              ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {
                    int monedasOfertadas = 0;
                    Gallo? galloFinal;
                    Gallina? gallinaFinal;

                    if (tipoOferta == 'monedas') {
                      monedasOfertadas = int.tryParse(monedasCtrl.text.trim()) ?? 0;
                      if (monedasOfertadas <= 0 || monedasOfertadas > monedas) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cantidad de monedas inválida')));
                        return;
                      }
                    } else if (tipoOferta == 'gallo') {
                      if (galloOfertado == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona un gallo para ofrecer')));
                        return;
                      }
                      galloFinal = galloOfertado;
                    } else if (tipoOferta == 'gallina') {
                      if (gallinaOfertada == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona una gallina para ofrecer')));
                        return;
                      }
                      gallinaFinal = gallinaOfertada;
                    }

                    Navigator.pop(context);

                    String intercambioID = '${miCodigoAmigo}_${DateTime.now().millisecondsSinceEpoch}';

                    setState(() {
                      if (monedasOfertadas > 0) monedas -= monedasOfertadas;
                      if (galloFinal != null) misGallos.removeWhere((g) => g.id == galloFinal!.id);
                      if (gallinaFinal != null) misGallinas.removeWhere((g) => g.id == gallinaFinal!.id);
                      _guardarDatos();
                    });

                    SolicitudIntercambio solicitud = SolicitudIntercambio(
                      idRemitente: miCodigoAmigo,
                      nombreRemitente: nombreUsuario,
                      galloOfrecido: galloFinal,
                      gallinaOfrecida: gallinaFinal,
                      monedasOfrecidas: monedasOfertadas,
                      intercambioID: intercambioID,
                    );

                    _enviarSolicitudIntercambioSupabase(idAmigo, solicitud);
                  },
                  child: const Text('Enviar Oferta'),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _aceptarIntercambioPendiente(SolicitudIntercambio it) async {
    setState(() {
      if (it.galloOfrecido != null) misGallos.add(it.galloOfrecido!);
      if (it.gallinaOfrecida != null) misGallinas.add(it.gallinaOfrecida!);
      if (it.monedasOfrecidas > 0) monedas += it.monedasOfrecidas;
      intercambiosPendientes.removeWhere((x) => x.intercambioID == it.intercambioID);
      _guardarDatos();
    });

    await _limpiarBuzonNube();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🤝 ¡Has aceptado el intercambio de ${it.nombreRemitente}!')));
  }

  void _rechazarIntercambioPendiente(SolicitudIntercambio it) async {
    setState(() {
      intercambiosPendientes.removeWhere((x) => x.intercambioID == it.intercambioID);
    });

    Map<String, dynamic> payload = {
      'tipo': 'rechazar_intercambio',
      'rechazoID': it.intercambioID,
      'galloDevuelto': it.galloOfrecido?.toJson(),
      'gallinaDevuelta': it.gallinaOfrecida?.toJson(),
      'monedasDevueltas': it.monedasOfrecidas,
    };

    try {
      await _enviarRechazoIntercambioSupabase(it.idRemitente, payload);
      await _limpiarBuzonNube();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Has rechazado el intercambio de ${it.nombreRemitente}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al rechazar intercambio: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=1200&q=80',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.45))),

          SafeArea(
            child: Column(
              children: [
                _barraSuperior(),
                Expanded(child: _construirSeccionActual()),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 55,
        color: Colors.black.withOpacity(0.9),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _botonNav(0, Icons.pets, 'Gallinero'),
            _botonNav(1, Icons.fitness_center, 'Entrenar'),
            _botonNav(2, Icons.egg, 'Cruces'),
            _botonNav(3, Icons.timer, 'Criadero'),
            _botonNav(4, Icons.sports_mma, 'Pelea'),
            _botonNav(5, Icons.auto_stories, 'Historia'),
            _botonNav(6, Icons.store, 'Tienda'),
            _botonNav(7, Icons.groups, 'Amigos'),
          ],
        ),
      ),
    );
  }

  Widget _barraSuperior() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: Colors.black87,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black54,
              side: const BorderSide(color: Colors.amber),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            ),
            onPressed: _abrirPerfil,
            icon: const Icon(Icons.person, color: Colors.amber, size: 14),
            label: Text(nombreUsuario.isNotEmpty ? nombreUsuario : 'Perfil', style: const TextStyle(color: Colors.white, fontSize: 10)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo[900],
              side: const BorderSide(color: Colors.cyanAccent),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            ),
            onPressed: _abrirPaseBatalla,
            icon: const Icon(Icons.military_tech, color: Colors.cyanAccent, size: 14),
            label: const Text('⚔️ Pase', style: TextStyle(color: Colors.white, fontSize: 10)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.cyanAccent)),
            child: Text(
              '⭐ Nvl $nivelPerfil | XP: $xpPerfil/$xpSiguienteNivel',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: Colors.amber[900], borderRadius: BorderRadius.circular(10)),
                child: Text('🪙 $monedas', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11)),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: Colors.cyan[900], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.cyanAccent)),
                child: Text('💎 $diamantes', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent, fontSize: 11)),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _botonNav(int index, IconData icono, String etiqueta) {
    bool sel = indicePestana == index;
    return InkWell(
      onTap: () => setState(() => indicePestana = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, color: sel ? Colors.amber : Colors.grey, size: 18),
          Text(etiqueta, style: TextStyle(fontSize: 8, color: sel ? Colors.amber : Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _construirSeccionActual() {
    switch (indicePestana) {
      case 0: return _vistaGallinero();
      case 1: return _vistaEntrenamiento();
      case 2: return _vistaCruces();
      case 3: return _vistaCriadero();
      case 4: return _vistaPeleaPropia();
      case 5: return _vistaHistoria();
      case 6: return _vistaTienda();
      case 7: return _vistaAmigosOnline();
      default: return _vistaGallinero();
    }
  }

  // ---------------------------------------------------------------------
  // VISTA: GALLINERO
  // ---------------------------------------------------------------------

  Widget _vistaGallinero() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🐓 Mis Gallos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber)),
          const SizedBox(height: 8),
          misGallos.isEmpty
              ? const Text('Todavía no tienes gallos.', style: TextStyle(color: Colors.grey))
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: misGallos.map((g) => _tarjetaGallo(g)).toList(),
                ),
          const SizedBox(height: 20),
          const Text('🐔 Mis Gallinas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.pinkAccent)),
          const SizedBox(height: 8),
          misGallinas.isEmpty
              ? const Text('Todavía no tienes gallinas.', style: TextStyle(color: Colors.grey))
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: misGallinas.map((g) => _tarjetaGallina(g)).toList(),
                ),
        ],
      ),
    );
  }

  Widget _tarjetaGallo(Gallo g) {
    return InkWell(
      onTap: () => _dialogoRenombrarGallo(g),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Color(g.colorPlumasValue), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: Color(g.colorPlumasValue), shape: BoxShape.circle),
                  child: const Center(child: Text('🐓', style: TextStyle(fontSize: 14))),
                ),
                const SizedBox(width: 4),
                Expanded(child: Text(g.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Rareza: ${g.rareza.name} | Nvl ${g.nivel}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const Divider(height: 8),
            Text('ATK ${g.ataque}  DEF ${g.defensa}', style: const TextStyle(fontSize: 10)),
            Text('VEL ${g.velocidad}  STA ${g.stamina}', style: const TextStyle(fontSize: 10)),
            Text('HP ${g.vidaMax}', style: const TextStyle(fontSize: 10)),
            if (g.entrenando) const Padding(padding: EdgeInsets.only(top: 4), child: Text('⏳ Entrenando...', style: TextStyle(fontSize: 10, color: Colors.cyanAccent))),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaGallina(Gallina g) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Color(g.colorPlumasValue), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: Color(g.colorPlumasValue), shape: BoxShape.circle),
                child: const Center(child: Text('🐔', style: TextStyle(fontSize: 14))),
              ),
              const SizedBox(width: 4),
              Expanded(child: Text(g.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Rareza: ${g.rareza.name}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // VISTA: ENTRENAMIENTO
  // ---------------------------------------------------------------------

  Widget _vistaEntrenamiento() {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: misGallos.length,
      itemBuilder: (context, index) {
        Gallo g = misGallos[index];
        bool listoParaFinalizar = g.entrenando && g.finEntrenamiento != null && DateTime.now().isAfter(g.finEntrenamiento!);
        Duration restante = g.entrenando && g.finEntrenamiento != null ? g.finEntrenamiento!.difference(DateTime.now()) : Duration.zero;
        if (restante.isNegative) restante = Duration.zero;

        return Card(
          color: Colors.black87,
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.nombre, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                Text('Costo de entrenamiento: 🪙 ${g.obtenerCostoEntrenamiento()}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 6),
                if (!g.entrenando)
                  Wrap(
                    spacing: 6,
                    children: ['Ataque', 'Defensa', 'Velocidad', 'Stamina'].map((tipo) {
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
                        onPressed: () {
                          if (monedas < g.obtenerCostoEntrenamiento()) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tienes suficientes monedas')));
                            return;
                          }
                          setState(() {
                            monedas -= g.obtenerCostoEntrenamiento();
                            g.iniciarEntrenamiento(tipo);
                            _guardarDatos();
                          });
                        },
                        child: Text(tipo, style: const TextStyle(fontSize: 11)),
                      );
                    }).toList(),
                  )
                else if (listoParaFinalizar)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () {
                      setState(() {
                        g.acelerarEntrenamientoConDiamantes();
                        _guardarDatos();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('¡${g.nombre} completó su entrenamiento!')));
                    },
                    child: const Text('Recoger Entrenamiento'),
                  )
                else
                  Row(
                    children: [
                      Text(
                        '⏳ ${g.tipoEntrenamiento}: ${restante.inMinutes}:${(restante.inSeconds % 60).toString().padLeft(2, '0')} restante',
                        style: const TextStyle(fontSize: 11, color: Colors.cyanAccent),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan[900]),
                        onPressed: diamantes < 5
                            ? null
                            : () {
                                setState(() {
                                  diamantes -= 5;
                                  g.acelerarEntrenamientoConDiamantes();
                                  _guardarDatos();
                                });
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('💎 ¡Entrenamiento acelerado!')));
                              },
                        child: const Text('💎 5 Acelerar', style: TextStyle(fontSize: 10)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // VISTA: CRUCES
  // ---------------------------------------------------------------------

  Widget _vistaCruces() {
    int costo = (galloCruce != null && gallinaCruce != null) ? obtenerCosteCruce(galloCruce!.rareza, gallinaCruce!.rareza) : 0;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🧬 Cruces de Genética', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amber)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text('Gallo: ${galloCruce != null ? galloCruce!.nombre : "Ninguno"}', style: const TextStyle(fontSize: 11)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: (galloCruce != null && gallinaCruce != null)
                    ? () {
                        if (monedas < costo) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tienes suficientes monedas para el cruce')));
                          return;
                        }
                        Rareza rarezaResultante = galloCruce!.rareza.index >= gallinaCruce!.rareza.index ? galloCruce!.rareza : gallinaCruce!.rareza;
                        setState(() {
                          monedas -= costo;
                          huevosCriadero.add(HuevoCriadero(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            rarezaPadres: rarezaResultante,
                            finIncubacion: DateTime.now().add(const Duration(minutes: 5)),
                          ));
                          galloCruce = null;
                          gallinaCruce = null;
                          _guardarDatos();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🥚 ¡Huevo enviado al Criadero! Tardará 5 min.')));
                      }
                    : null,
                icon: const Icon(Icons.egg),
                label: Text(costo > 0 ? 'Cruzar (🪙 $costo)' : 'Cruzar'),
              ),
              Text('Gallina: ${gallinaCruce != null ? gallinaCruce!.nombre : "Ninguna"}', style: const TextStyle(fontSize: 11)),
            ],
          ),
          const Divider(),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: misGallos.length,
                    itemBuilder: (context, index) {
                      Gallo g = misGallos[index];
                      bool sel = galloCruce?.id == g.id;
                      return ListTile(
                        dense: true,
                        title: Text(g.nombre, style: const TextStyle(fontSize: 11)),
                        subtitle: Text(g.rareza.name.toUpperCase(), style: const TextStyle(fontSize: 9, color: Colors.grey)),
                        trailing: Icon(Icons.check_circle, color: sel ? Colors.amber : Colors.grey),
                        onTap: () => setState(() => galloCruce = g),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: misGallinas.length,
                    itemBuilder: (context, index) {
                      Gallina g = misGallinas[index];
                      bool sel = gallinaCruce?.id == g.id;
                      return ListTile(
                        dense: true,
                        title: Text(g.nombre, style: const TextStyle(fontSize: 11)),
                        subtitle: Text(g.rareza.name.toUpperCase(), style: const TextStyle(fontSize: 9, color: Colors.grey)),
                        trailing: Icon(Icons.check_circle, color: sel ? Colors.pinkAccent : Colors.grey),
                        onTap: () => setState(() => gallinaCruce = g),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // VISTA: CRIADERO (5 Minutos con Aceleración Activa)
  // ---------------------------------------------------------------------

  Widget _vistaCriadero() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🐣 Criadero de Huevos (5 min de Incubación)', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Expanded(
            child: huevosCriadero.isEmpty
                ? const Center(child: Text('No hay huevos en incubación.'))
                : ListView.builder(
                    itemCount: huevosCriadero.length,
                    itemBuilder: (context, index) {
                      HuevoCriadero huevo = huevosCriadero[index];
                      int restante = huevo.finIncubacion.difference(DateTime.now()).inSeconds;
                      bool listo = restante <= 0;

                      int m = max(0, restante) ~/ 60;
                      int s = max(0, restante) % 60;

                      return Card(
                        color: Colors.black87,
                        child: ListTile(
                          leading: const Icon(Icons.egg_sharp, color: Colors.amber, size: 30),
                          title: Text('Huevo Genética ${huevo.rarezaPadres.name.toUpperCase()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            listo ? '¡Listo para romper el cascarón!' : '⏳ Restan: ${m}m ${s}s',
                            style: TextStyle(color: listo ? Colors.greenAccent : Colors.cyanAccent, fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!listo) ...[
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
                                  onPressed: monedas >= 150
                                      ? () {
                                          setState(() {
                                            monedas -= 150;
                                            huevo.finIncubacion = DateTime.now().subtract(const Duration(seconds: 1));
                                            _guardarDatos();
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.flash_on, size: 14),
                                  label: const Text('Acelerar (🪙 150)', style: TextStyle(fontSize: 10)),
                                ),
                                const SizedBox(width: 4),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan[900]),
                                  onPressed: diamantes >= 5
                                      ? () {
                                          setState(() {
                                            diamantes -= 5;
                                            huevo.finIncubacion = DateTime.now().subtract(const Duration(seconds: 1));
                                            _guardarDatos();
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.flash_on, size: 14, color: Colors.cyanAccent),
                                  label: const Text('Acelerar (💎 5)', style: TextStyle(fontSize: 10)),
                                ),
                              ],
                              const SizedBox(width: 4),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: listo ? Colors.green : Colors.grey),
                                onPressed: listo
                                    ? () {
                                        setState(() {
                                          huevosCriadero.removeAt(index);
                                          _guardarDatos();
                                        });
                                        Random r = Random();
                                        if (r.nextBool()) {
                                          Gallo nuevoG = Gallo.generarAleatorio(nombrePersonalizado: 'Cría', rareza: huevo.rarezaPadres);
                                          _dialogoNombrarRecompensaPase(nuevoG);
                                        } else {
                                          Gallina nuevaGa = Gallina.generarAleatoria(nombrePersonalizado: 'Cría', rareza: huevo.rarezaPadres);
                                          _dialogoNombrarRecompensaPase(nuevaGa);
                                        }
                                      }
                                    : null,
                                child: const Text('Eclosionar', style: TextStyle(fontSize: 10)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // VISTA: PELEA PROPIA (Gallo vs Gallo Propio)
  // ---------------------------------------------------------------------

  Widget _vistaPeleaPropia() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          const Text('⚔️ Pelea de Exhibición (Gallo vs Gallo Propio)', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          const Text('Gana XP de Perfil probando tus propios gallos (Sin monedas)', style: TextStyle(fontSize: 11, color: Colors.cyanAccent)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: misGallos.length,
              itemBuilder: (context, i) {
                final g = misGallos[i];
                bool sel1 = galloPelea1 == g;
                bool sel2 = galloPelea2 == g;

                return Card(
                  color: Colors.black87,
                  child: ListTile(
                    dense: true,
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: Color(g.colorPlumasValue), shape: BoxShape.circle),
                      child: const Center(child: Text('🐓', style: TextStyle(fontSize: 16))),
                    ),
                    title: Text(g.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    subtitle: Text('ATK: ${g.ataque} | DEF: ${g.defensa} | HP: ${g.vidaMax}', style: const TextStyle(fontSize: 10, color: Colors.amberAccent)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.looks_one, color: sel1 ? Colors.amber : Colors.grey),
                          onPressed: () => setState(() => galloPelea1 = sel1 ? null : g),
                        ),
                        IconButton(
                          icon: Icon(Icons.looks_two, color: sel2 ? Colors.redAccent : Colors.grey),
                          onPressed: () => setState(() => galloPelea2 = sel2 ? null : g),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            onPressed: () {
              if (galloPelea1 != null && galloPelea2 != null && galloPelea1 != galloPelea2) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PantallaPeleaRealista(
                      galloJugador: galloPelea1!,
                      galloRival: galloPelea2!,
                      esBoss: false,
                      nivelActual: 0,
                      apuestaMonedas: 0,
                      semillaCombate: DateTime.now().millisecondsSinceEpoch,
                      onResultadoApuesta: (m) {},
                      onGanaXP: () {
                        _agregarXP(40);
                      },
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona 2 gallos distintos de tu gallinero')));
              }
            },
            icon: const Icon(Icons.sports_mma),
            label: const Text('Iniciar Combate (+40 XP)'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // VISTA: HISTORIA (Exactamente 500 Niveles con Selección de Gallo)
  // ---------------------------------------------------------------------

  Widget _vistaHistoria() {
    int nivelesTotales = 500;

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: nivelesTotales,
      itemBuilder: (context, index) {
        int nivel = index + 1;
        bool desbloqueado = nivel <= nivelHistoriaMaximo;
        bool esBoss = nivel % 10 == 0; // Cada 10 niveles es un Boss

        return Card(
          color: desbloqueado ? Colors.black87 : Colors.grey[900],
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: Icon(esBoss ? Icons.emoji_events : Icons.flag, color: desbloqueado ? (esBoss ? Colors.redAccent : Colors.amber) : Colors.grey),
            title: Text('Nivel $nivel${esBoss ? ' — BOSS' : ''}', style: TextStyle(color: desbloqueado ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
            subtitle: Text(desbloqueado ? 'Toca para luchar' : 'Bloqueado', style: const TextStyle(fontSize: 11)),
            trailing: desbloqueado
                ? ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: esBoss ? Colors.redAccent : Colors.amber[800]),
                    onPressed: misGallos.isEmpty
                        ? null
                        : () => _dialogoSeleccionarGalloParaHistoria(nivel, esBoss),
                    child: const Text('Luchar', style: TextStyle(fontSize: 11)),
                  )
                : const Icon(Icons.lock, color: Colors.grey),
          ),
        );
      },
    );
  }

  void _dialogoSeleccionarGalloParaHistoria(int nivel, bool esBoss) {
    if (misGallos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tienes gallos en tu gallinero')));
      return;
    }

    Gallo galloElegido = misGallos.first;

    showDialog(
      context: context,
      builder: (c) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2C2C2C),
              title: Text('🐓 Seleccionar Gallo para Nivel $nivel'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Elige qué gallo irá al combate:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 10),
                  DropdownButton<Gallo>(
                    value: galloElegido,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF3C3C3C),
                    items: misGallos.map((g) {
                      return DropdownMenuItem<Gallo>(
                        value: g,
                        child: Text('${g.nombre} (Nvl ${g.nivel} | ATK: ${g.ataque})', style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => galloElegido = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
                  onPressed: () {
                    Navigator.pop(c);
                    Rareza rarezaRival = Rareza.values[min(Rareza.values.length - 1, (nivel ~/ 100))];
                    Gallo rivalHistoria = Gallo.generarAleatorio(
                      nombrePersonalizado: esBoss ? '👑 BOSS Nivel $nivel' : 'Rival Nivel $nivel',
                      rareza: rarezaRival,
                      nivelBonus: nivel,
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PantallaPeleaRealista(
                          galloJugador: galloElegido,
                          galloRival: rivalHistoria,
                          esBoss: esBoss,
                          nivelActual: nivel,
                          apuestaMonedas: 0,
                          semillaCombate: DateTime.now().millisecondsSinceEpoch,
                          onResultadoApuesta: (ganado) {
                            setState(() {
                              if (ganado) {
                                monedas += 30 * nivel;
                                if (nivel == nivelHistoriaMaximo && nivelHistoriaMaximo < 500) {
                                  nivelHistoriaMaximo++;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🎉 ¡Nivel $nivel superado! +🪙 ${30 * nivel}')));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('💀 Derrota, inténtalo de nuevo')));
                              }
                              _guardarDatos();
                            });
                          },
                          onGanaXP: () => _agregarXP(30 + nivel),
                        ),
                      ),
                    );
                  },
                  child: const Text('¡Comenzar Pelea!'),
                )
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // VISTA: TIENDA
  // ---------------------------------------------------------------------

  Widget _vistaTienda() {
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        const Text('🐔 Gallinas en Venta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.pinkAccent)),
        const SizedBox(height: 8),
        ...Rareza.values.map((r) {
          int precio = obtenerPrecioGallina(r);
          return Card(
            color: Colors.black87,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.egg, color: Colors.pinkAccent),
              title: Text('Gallina ${r.name}'),
              subtitle: Text('🪙 $precio Monedas'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
                onPressed: monedas >= precio
                    ? () {
                        setState(() {
                          monedas -= precio;
                          misGallinas.add(Gallina.generarAleatoria(nombrePersonalizado: 'Gallina ${r.name}', rareza: r));
                          _guardarDatos();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Gallina comprada!')));
                      }
                    : null,
                child: const Text('Comprar', style: TextStyle(fontSize: 11)),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // VISTA: AMIGOS ONLINE
  // ---------------------------------------------------------------------

  Widget _vistaAmigosOnline() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.black87,
            child: TabBar(
              indicatorColor: Colors.amber,
              tabs: [
                Tab(text: 'Amigos (${amigosAgregados.length})'),
                Tab(text: 'Peleas (${peleasPendientes.length})'),
                Tab(text: 'Intercambios (${intercambiosPendientes.length})'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.cyanAccent)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.badge, color: Colors.cyanAccent, size: 20),
                            const SizedBox(width: 8),
                            Text('Mi ID Único de Amigo: $miCodigoAmigo', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controllerIDAmigo,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              decoration: const InputDecoration(
                                counterText: '',
                                hintText: 'Escribe el ID de 4 cifras de tu amigo...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                            onPressed: _agregarAmigo,
                            icon: const Icon(Icons.person_add, size: 18),
                            label: const Text('AGREGAR'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: amigosAgregados.isEmpty
                            ? const Center(child: Text('Aún no has agregado ningún amigo.'))
                            : ListView.builder(
                                itemCount: amigosAgregados.length,
                                itemBuilder: (context, i) {
                                  final amigo = amigosAgregados[i];
                                  return Card(
                                    color: Colors.black87,
                                    child: ListTile(
                                      title: Text('Amigo ID: $amigo', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                            onPressed: () => _enviarPeticionPelea(amigo),
                                            child: const Text('Retar', style: TextStyle(fontSize: 10)),
                                          ),
                                          const SizedBox(width: 4),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                                            onPressed: () => _dialogoEnviarIntercambio(amigo),
                                            child: const Text('Intercambiar', style: TextStyle(fontSize: 10)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: peleasPendientes.isEmpty
                      ? const Center(child: Text('No tienes solicitudes de pelea pendientes.'))
                      : ListView.builder(
                          itemCount: peleasPendientes.length,
                          itemBuilder: (context, i) {
                            final sol = peleasPendientes[i];
                            return Card(
                              color: Colors.black87,
                              child: ListTile(
                                leading: const Icon(Icons.sports_mma, color: Colors.redAccent, size: 28),
                                title: Text('Reto de ${sol.nombreRetador} (ID ${sol.idRetador})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text('Apuesta: 🪙 ${sol.apuesta} Monedas\nOfrece Gallo: ${sol.galloRetador.nombre}', style: const TextStyle(color: Colors.amberAccent, fontSize: 11)),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                      onPressed: () => _aceptarPeleaPendiente(sol),
                                      child: const Text('Aceptar', style: TextStyle(fontSize: 10)),
                                    ),
                                    const SizedBox(width: 4),
                                    TextButton(
                                      onPressed: () => _rechazarPeleaPendiente(sol),
                                      child: const Text('Rechazar', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: intercambiosPendientes.isEmpty
                      ? const Center(child: Text('No tienes solicitudes de intercambio pendientes.'))
                      : ListView.builder(
                          itemCount: intercambiosPendientes.length,
                          itemBuilder: (context, i) {
                            final inter = intercambiosPendientes[i];
                            return Card(
                              color: Colors.black87,
                              child: ListTile(
                                leading: const Icon(Icons.swap_horiz, color: Colors.cyanAccent, size: 28),
                                title: Text('Intercambio de ${inter.nombreRemitente} (ID ${inter.idRemitente})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text(
                                  inter.galloOfrecido != null ? 'Ofrece Gallo: ${inter.galloOfrecido!.nombre} (${inter.galloOfrecido!.rareza.name})' : (inter.gallinaOfrecida != null ? 'Ofrece Gallina: ${inter.gallinaOfrecida!.nombre}' : 'Ofrece: 🪙 ${inter.monedasOfrecidas} Monedas'),
                                  style: const TextStyle(fontSize: 11, color: Colors.amberAccent),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                      onPressed: () => _aceptarIntercambioPendiente(inter),
                                      child: const Text('Aceptar', style: TextStyle(fontSize: 10)),
                                    ),
                                    const SizedBox(width: 4),
                                    TextButton(
                                      onPressed: () => _rechazarIntercambioPendiente(inter),
                                      child: const Text('Rechazar', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SolicitudPelea {
  final String idRetador;
  final String nombreRetador;
  final int apuesta;
  final Gallo galloRetador;
  final int combateID;

  SolicitudPelea({
    required this.idRetador,
    required this.nombreRetador,
    required this.apuesta,
    required this.galloRetador,
    required this.combateID,
  });
}

class SolicitudIntercambio {
  final String idRemitente;
  final String nombreRemitente;
  final Gallo? galloOfrecido;
  final Gallina? gallinaOfrecida;
  final int monedasOfrecidas;
  final String intercambioID;

  SolicitudIntercambio({
    required this.idRemitente,
    required this.nombreRemitente,
    this.galloOfrecido,
    this.gallinaOfrecida,
    required this.monedasOfrecidas,
    required this.intercambioID,
  });
}

class PantallaPeleaRealista extends StatefulWidget {
  final Gallo galloJugador;
  final Gallo galloRival;
  final bool esBoss;
  final int nivelActual;
  final int apuestaMonedas;
  final int semillaCombate;
  final Function(bool) onResultadoApuesta;
  final Function() onGanaXP;

  const PantallaPeleaRealista({
    super.key,
    required this.galloJugador,
    required this.galloRival,
    required this.esBoss,
    required this.nivelActual,
    required this.apuestaMonedas,
    required this.semillaCombate,
    required this.onResultadoApuesta,
    required this.onGanaXP,
  });

  @override
  State<PantallaPeleaRealista> createState() => _PantallaPeleaRealistaState();
}

class _PantallaPeleaRealistaState extends State<PantallaPeleaRealista> {
  late int hp1, hp2;
  int turnoRonda = 0;
  Timer? timerCombate;
  String logPelea = '¡Combate sincronizado en curso!';
  String ganadorText = '';
  bool recompensaDada = false;

  bool gallo1Atacando = false;
  bool gallo2Atacando = false;
  late Random randCombate;

  List<String> fondosHD = [
    'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1516253593875-bd7ba052fbc5?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1509316975850-ff9c5deb0cd9?auto=format&fit=crop&w=1200&q=80',
  ];
  late String fondoElegido;

  @override
  void initState() {
    super.initState();
    hp1 = widget.galloJugador.vidaMax;
    hp2 = widget.galloRival.vidaMax;
    randCombate = Random(widget.semillaCombate);
    fondoElegido = fondosHD[randCombate.nextInt(fondosHD.length)];

    timerCombate = Timer.periodic(const Duration(milliseconds: 1200), (t) {
      if (hp1 <= 0 || hp2 <= 0 || ganadorText.isNotEmpty) {
        t.cancel();
        _finalizarCombate();
        return;
      }

      setState(() {
        turnoRonda++;
        gallo1Atacando = true;
      });

      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        setState(() {
          gallo1Atacando = false;
          int variacionCritica = randCombate.nextBool() ? 5 : 0;
          int d1 = max(3, (widget.galloJugador.ataque - (widget.galloRival.defensa ~/ 2)) + variacionCritica);
          hp2 = max(0, hp2 - d1);
          logPelea = '💥 ${widget.galloJugador.nombre} ataca y causa $d1 de daño!';

          if (hp2 <= 0) {
            _finalizarCombate();
            return;
          }

          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted || hp1 <= 0) return;
            setState(() {
              gallo2Atacando = true;
            });

            Future.delayed(const Duration(milliseconds: 400), () {
              if (!mounted) return;
              setState(() {
                gallo2Atacando = false;
                int variacionRival = randCombate.nextBool() ? 4 : 0;
                int d2 = max(3, (widget.galloRival.ataque - (widget.galloJugador.defensa ~/ 2)) + variacionRival);
                hp1 = max(0, hp1 - d2);
                logPelea = '⚡ ${widget.galloRival.nombre} counter-ataca y causa $d2 de daño!';

                if (hp1 <= 0) {
                  _finalizarCombate();
                }
              });
            });
          });
        });
      });
    });
  }

  void _finalizarCombate() {
    if (recompensaDada) return;

    timerCombate?.cancel();

    setState(() {
      bool victoria = hp2 <= 0 || (hp1 > hp2 && hp1 > 0);
      if (victoria) {
        ganadorText = '🏆 ¡VICTORIA!';
        widget.onResultadoApuesta(true);
        widget.onGanaXP();
      } else {
        ganadorText = '💀 DERROTA...';
        widget.onResultadoApuesta(false);
      }
      recompensaDada = true;
    });
  }

  @override
  void dispose() {
    timerCombate?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double centroOffset = (screenWidth / 2) - 110;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.network(fondoElegido, fit: BoxFit.cover)),
          Positioned.fill(child: Container(color: Colors.black38)),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            left: gallo1Atacando ? centroOffset + 30 : centroOffset,
            bottom: gallo1Atacando ? 75 : 30,
            child: CustomPaint(
              size: const Size(130, 130),
              painter: GalloPixelPainter(
                colorCuerpo: Color(widget.galloJugador.colorPlumasValue),
                atacando: gallo1Atacando,
              ),
            ),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            right: gallo2Atacando ? centroOffset + 30 : centroOffset,
            bottom: gallo2Atacando ? 75 : 30,
            child: Transform.flip(
              flipX: true,
              child: CustomPaint(
                size: const Size(130, 130),
                painter: GalloPixelPainter(
                  colorCuerpo: Color(widget.galloRival.colorPlumasValue),
                  atacando: gallo2Atacando,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black87),
                        child: const Text('Salir'),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: Text(
                          '⚔️ RONDA $turnoRonda',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.amber),
                        ),
                      ),
                      Text(widget.esBoss ? '👑 BOSS NIVEL ${widget.nivelActual}' : (widget.nivelActual > 0 ? 'NIVEL ${widget.nivelActual}' : 'APUESTA: 🪙 ${widget.apuestaMonedas}'), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      ganadorText.isNotEmpty ? ganadorText : logPelea,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ganadorText.isNotEmpty ? Colors.greenAccent : Colors.white),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _barraVidaHud(widget.galloJugador, hp1, Colors.amber)),
                      const SizedBox(width: 16),
                      Expanded(child: _barraVidaHud(widget.galloRival, hp2, Colors.redAccent)),
                    ],
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _barraVidaHud(Gallo g, int hpActual, Color col) {
    double pct = (hpActual / g.vidaMax).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8), border: Border.all(color: col)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(g.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 2),
          LinearProgressIndicator(value: pct, color: Colors.green, backgroundColor: Colors.grey[800], minHeight: 6),
        ],
      ),
    );
  }
}

class GalloPixelPainter extends CustomPainter {
  final Color colorCuerpo;
  final bool atacando;
  GalloPixelPainter({required this.colorCuerpo, required this.atacando});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    double w = size.width / 16;
    double h = size.height / 16;

    paint.color = Colors.red;
    canvas.drawRect(Rect.fromLTWH(8 * w, 1 * h, 4 * w, 3 * h), paint);

    paint.color = Colors.orangeAccent;
    canvas.drawRect(Rect.fromLTWH(7 * w, 4 * h, 4 * w, 4 * h), paint);

    paint.color = Colors.amber;
    canvas.drawRect(Rect.fromLTWH(11 * w, 4.5 * h, 2 * w, 1.5 * h), paint);

    paint.color = colorCuerpo;
    canvas.drawRect(Rect.fromLTWH(4 * w, 7 * h, 8 * w, 6 * h), paint);

    canvas.drawRect(Rect.fromLTWH(1 * w, 3 * h, 4 * w, 8 * h), paint);

    if (atacando) {
      paint.color = Colors.black45;
      canvas.drawRect(Rect.fromLTWH(2 * w, 4 * h, 6 * w, 4 * h), paint);
      paint.color = Colors.amber;
      canvas.drawRect(Rect.fromLTWH(11 * w, 11 * h, 3 * w, 1 * h), paint);
      canvas.drawRect(Rect.fromLTWH(12 * w, 12 * h, 3 * w, 1 * h), paint);
    } else {
      paint.color = Colors.amber;
      canvas.drawRect(Rect.fromLTWH(7 * w, 13 * h, 1 * w, 3 * h), paint);
      canvas.drawRect(Rect.fromLTWH(9 * w, 13 * h, 1 * w, 3 * h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}