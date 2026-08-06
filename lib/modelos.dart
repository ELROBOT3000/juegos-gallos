import 'dart:math';
import 'package:flutter/material.dart';

enum Rareza { sevillano, ingles, shamo, minino, calcuta }

int obtenerPrecioGallina(Rareza r) {
  switch (r) {
    case Rareza.sevillano: return 300;
    case Rareza.ingles: return 600;
    case Rareza.shamo: return 1200;
    case Rareza.minino: return 2500;
    case Rareza.calcuta: return 5000;
  }
}

int obtenerCosteCruce(Rareza p1, Rareza p2) {
  int base = 200;
  return base + (p1.index + p2.index) * 150;
}

class Gallo {
  String id;
  String nombre;
  Rareza rareza;
  int nivel;
  int ataque;
  int defensa;
  int velocidad;
  int stamina;
  int vidaMax;
  int colorPlumasValue;
  bool entrenando;
  String? tipoEntrenamiento;
  DateTime? finEntrenamiento;

  Gallo({
    required this.id,
    required this.nombre,
    required this.rareza,
    required this.nivel,
    required this.ataque,
    required this.defensa,
    required this.velocidad,
    required this.stamina,
    required this.vidaMax,
    required this.colorPlumasValue,
    this.entrenando = false,
    this.tipoEntrenamiento,
    this.finEntrenamiento,
  });

  factory Gallo.generarAleatorio({required String nombrePersonalizado, required Rareza rareza, int nivelBonus = 1}) {
    int multiplicador = rareza.index + 1;
    Random r = Random();
    
    int atk = 20 + ((r.nextInt(10) * multiplicador) + (nivelBonus * 2));
    int def = 10 + ((r.nextInt(6) * multiplicador) + nivelBonus);
    int vel = 15 + ((r.nextInt(8) * multiplicador) + nivelBonus);
    int stam = 50 + ((r.nextInt(20) * multiplicador) + (nivelBonus * 5));
    int hp = 100 + ((r.nextInt(30) * multiplicador) + (nivelBonus * 10));

    List<Color> colores = [Colors.red, Colors.amber, Colors.blue, Colors.green, Colors.purple, Colors.orange];
    int colorVal = colores[r.nextInt(colores.length)].value;

    return Gallo(
      id: DateTime.now().millisecondsSinceEpoch.toString() + r.nextInt(1000).toString(),
      nombre: nombrePersonalizado,
      rareza: rareza,
      nivel: nivelBonus,
      ataque: atk,
      defensa: def,
      velocidad: vel,
      stamina: stam,
      vidaMax: hp,
      colorPlumasValue: colorVal,
    );
  }

  int obtenerCostoEntrenamiento() {
    return 50 * nivel;
  }

  void iniciarEntrenamiento(String tipo) {
    entrenando = true;
    tipoEntrenamiento = tipo;
    finEntrenamiento = DateTime.now().add(const Duration(seconds: 30));
  }

  void acelerarEntrenamientoConDiamantes() {
    if (!entrenando) return;
    if (tipoEntrenamiento == 'Ataque') ataque += 5;
    if (tipoEntrenamiento == 'Defensa') defensa += 4;
    if (tipoEntrenamiento == 'Velocidad') velocidad += 4;
    if (tipoEntrenamiento == 'Stamina') stamina += 12;
    nivel++;
    vidaMax += 10;
    entrenando = false;
    tipoEntrenamiento = null;
    finEntrenamiento = null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'rareza': rareza.index,
        'nivel': nivel,
        'ataque': ataque,
        'defensa': defensa,
        'velocidad': velocidad,
        'stamina': stamina,
        'vidaMax': vidaMax,
        'colorPlumasValue': colorPlumasValue,
        'entrenando': entrenando,
        'tipoEntrenamiento': tipoEntrenamiento,
        'finEntrenamiento': finEntrenamiento?.toIso8601String(),
      };

  factory Gallo.fromJson(Map<String, dynamic> json) {
    return Gallo(
      id: json['id'] ?? '',
      nombre: json['nombre'] ?? 'Gallo',
      rareza: Rareza.values[(json['rareza'] as num?)?.toInt() ?? 0],
      nivel: (json['nivel'] as num?)?.toInt() ?? 1,
      ataque: (json['ataque'] as num?)?.toInt() ?? 20,
      defensa: (json['defensa'] as num?)?.toInt() ?? 10,
      velocidad: (json['velocidad'] as num?)?.toInt() ?? 15,
      stamina: (json['stamina'] as num?)?.toInt() ?? 50,
      vidaMax: (json['vidaMax'] as num?)?.toInt() ?? 100,
      colorPlumasValue: (json['colorPlumasValue'] as num?)?.toInt() ?? Colors.red.value,
      entrenando: json['entrenando'] ?? false,
      tipoEntrenamiento: json['tipoEntrenamiento'],
      finEntrenamiento: json['finEntrenamiento'] != null ? DateTime.parse(json['finEntrenamiento']) : null,
    );
  }
}

class Gallina {
  String id;
  String nombre;
  Rareza rareza;
  int colorPlumasValue;

  Gallina({
    required this.id,
    required this.nombre,
    required this.rareza,
    required this.colorPlumasValue,
  });

  factory Gallina.generarAleatoria({required String nombrePersonalizado, required Rareza rareza}) {
    Random r = Random();
    List<Color> colores = [Colors.pink, Colors.orangeAccent, Colors.purpleAccent, Colors.teal, Colors.brown];
    int colorVal = colores[r.nextInt(colores.length)].value;

    return Gallina(
      id: DateTime.now().millisecondsSinceEpoch.toString() + r.nextInt(1000).toString(),
      nombre: nombrePersonalizado,
      rareza: rareza,
      colorPlumasValue: colorVal,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'rareza': rareza.index,
        'colorPlumasValue': colorPlumasValue,
      };

  factory Gallina.fromJson(Map<String, dynamic> json) {
    return Gallina(
      id: json['id'] ?? '',
      nombre: json['nombre'] ?? 'Gallina',
      rareza: Rareza.values[(json['rareza'] as num?)?.toInt() ?? 0],
      colorPlumasValue: (json['colorPlumasValue'] as num?)?.toInt() ?? Colors.pink.value,
    );
  }
}

class HuevoCriadero {
  String id;
  Rareza rarezaPadres;
  DateTime finIncubacion;

  HuevoCriadero({required this.id, required this.rarezaPadres, required this.finIncubacion});

  Map<String, dynamic> toJson() => {
        'id': id,
        'rarezaPadres': rarezaPadres.index,
        'finIncubacion': finIncubacion.toIso8601String(),
      };

  factory HuevoCriadero.fromJson(Map<String, dynamic> json) {
    return HuevoCriadero(
      id: json['id'] ?? '',
      rarezaPadres: Rareza.values[(json['rarezaPadres'] as num?)?.toInt() ?? 0],
      finIncubacion: DateTime.parse(json['finIncubacion']),
    );
  }
}