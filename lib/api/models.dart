// ── Modelos ───────────────────────────────────────────────────────────────────

class Usuario {
  final String id;
  final String nombre;
  final String apellido;
  final String email;
  final String rol;
  final String? foto;

  const Usuario({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.rol,
    this.foto,
  });

  String get nombreCompleto => '$nombre $apellido';

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
    id:       j['uuid_publico'] ?? j['id'].toString(),
    nombre:   j['nombre'] ?? '',
    apellido: j['apellido'] ?? '',
    email:    j['email'] ?? '',
    rol:      j['rol'] ?? '',
    foto:     j['foto'],
  );
}

class Cuota {
  final String id;
  final String periodo;
  final double monto;
  final String estado;
  final DateTime fechaVencimiento;
  final String? notaAdmin;

  const Cuota({
    required this.id,
    required this.periodo,
    required this.monto,
    required this.estado,
    required this.fechaVencimiento,
    this.notaAdmin,
  });

  bool get vencida => estado == 'vencida';
  bool get enRevision => estado == 'en_revision';
  bool get pagada => estado == 'pagada';

  factory Cuota.fromJson(Map<String, dynamic> j) => Cuota(
    id:               j['uuid_publico'] ?? j['id'].toString(),
    periodo:          j['periodo'] ?? '',
    monto:            (j['monto'] as num).toDouble(),
    estado:           j['estado'] ?? '',
    fechaVencimiento: DateTime.parse(j['fecha_vencimiento']),
    notaAdmin:        j['nota_admin'],
  );
}

class AbonoArreglo {
  final String id;
  final int numero;
  final double monto;
  final DateTime fechaPactada;
  final String estado;

  const AbonoArreglo({
    required this.id,
    required this.numero,
    required this.monto,
    required this.fechaPactada,
    required this.estado,
  });

  factory AbonoArreglo.fromJson(Map<String, dynamic> j) => AbonoArreglo(
    id:           j['uuid_publico'] ?? j['id'].toString(),
    numero:       j['numero'] ?? 0,
    monto:        (j['monto'] as num).toDouble(),
    fechaPactada: DateTime.parse(j['fecha_pactada']),
    estado:       j['estado'] ?? '',
  );
}

class PagoHistorial {
  final String id;
  final double monto;
  final String estado;
  final String metodo;
  final DateTime fecha;
  final String? reciboNumero;

  const PagoHistorial({
    required this.id,
    required this.monto,
    required this.estado,
    required this.metodo,
    required this.fecha,
    this.reciboNumero,
  });

  factory PagoHistorial.fromJson(Map<String, dynamic> j) => PagoHistorial(
    id:           j['uuid_publico'] ?? j['id'].toString(),
    monto:        (j['monto'] as num).toDouble(),
    estado:       j['estado'] ?? '',
    metodo:       j['metodo'] ?? '',
    fecha:        DateTime.parse(j['creado_en'] ?? j['fecha']),
    reciboNumero: j['recibo_numero'],
  );
}

class EventoAcceso {
  final String id;
  final String nombreVisitante;
  final String tipoQr;
  final DateTime hora;
  final String resultado;
  final String? foto1;
  final String? foto2;
  final String? foto3;

  const EventoAcceso({
    required this.id,
    required this.nombreVisitante,
    required this.tipoQr,
    required this.hora,
    required this.resultado,
    this.foto1,
    this.foto2,
    this.foto3,
  });

  factory EventoAcceso.fromJson(Map<String, dynamic> j) => EventoAcceso(
    id:               j['uuid_publico'] ?? j['id'].toString(),
    nombreVisitante:  j['nombre_visitante'] ?? 'Desconocido',
    tipoQr:           j['tipo_qr'] ?? '',
    hora:             DateTime.parse(j['creado_en'] ?? j['hora']),
    resultado:        j['resultado'] ?? '',
    foto1:            j['foto_1'],
    foto2:            j['foto_2'],
    foto3:            j['foto_3'],
  );
}
