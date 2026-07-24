class Cultura {
  final String id;
  final String nome;
  final int? cicloDias;
  final List<Map<String, dynamic>>? operacoes;  // ← ADICIONE ESTE CAMPO

  Cultura({
    required this.id,
    required this.nome,
    this.cicloDias,
    this.operacoes,  // ← ADICIONE
  });

  factory Cultura.fromMap(Map<String, dynamic> map) {
    return Cultura(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      cicloDias: map['ciclo_dias'],
      operacoes: map['operacoes'] != null 
          ? List<Map<String, dynamic>>.from(map['operacoes']) 
          : null,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'ciclo_dias': cicloDias,
      'operacoes': operacoes,
    };
  }
}