import '../../../domain/models.dart' show AccessRole;

String teamRoleLabel(String? wire) => switch (wire) {
  null => 'Sem função atribuída',
  'campaignSupervisor' => 'Supervisor(a) das campanhas',
  'campaignDeputy' => 'Vice-supervisor(a) das campanhas',
  'discipleshipCoordinator' => 'Coordenador(a) do discipulado',
  'discipleshipDeputy' => 'Vice-coordenador(a) do discipulado',
  'coordinationSecretary' => 'Secretário(a) da coordenação',
  'coordinationDeputySecretary' => 'Vice-secretário(a) da coordenação',
  'congregationAssistant' => 'Assistente de congregação',
  'campaignLeader' => 'Dirigente de campanha',
  'campaignDeputyLeader' => 'Vice-dirigente de campanha',
  'teacher' => 'Professor(a) do discipulado',
  'discipleshipSecretary' => 'Secretário(a) do discipulado',
  'discipleshipDeputySecretary' => 'Vice-secretário(a) do discipulado',
  _ => 'Função cadastrada',
};

String teamAccessRoleLabel(AccessRole role) => switch (role) {
  AccessRole.direction => 'Direção da congregação',
  AccessRole.supervision => 'Supervisão geral',
};
