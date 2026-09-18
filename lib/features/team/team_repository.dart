/// Typed directory queries and contact mutations for the team feature
/// (S04, S05, S06, S09, S11).
///
/// The repository is the only place that knows the wire shape of the six S06
/// operations; widgets talk to typed drafts and commands and never to Firebase.
library;

import 'package:uuid/uuid.dart';

import '../../data/query_codec.dart';
import '../../domain/common.dart';
import '../../domain/contact.dart';
import '../../domain/ports.dart';

/// The minimal authenticated directory projection (S04).
///
/// It deliberately carries no birth date, address, student field or display
/// congregation name: the name is resolved from the authorized congregation
/// catalog by ID (S06), never fabricated in the projection.
class DirectoryEntry {
  const DirectoryEntry({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.scope,
    this.roleCode,
    this.congregationId,
    this.phoneE164,
  });

  final String id;
  final String name;
  final String normalizedName;
  final ContactScope scope;
  final RoleCode? roleCode;
  final String? congregationId;
  final String? phoneE164;

  String? get roleLabel => roleCode?.label;

  factory DirectoryEntry.fromJson(JsonMap json) {
    final String? role = optionalString(json, 'roleCode');
    return DirectoryEntry(
      id: requireString(json, 'id'),
      name: requireString(json, 'name'),
      normalizedName: requireString(json, 'normalizedName'),
      scope: ContactScope.fromWire(requireString(json, 'scope')),
      roleCode: role == null ? null : RoleCode.fromWire(role),
      congregationId: optionalString(json, 'congregationId'),
      phoneE164: optionalString(json, 'phoneE164'),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'normalizedName': normalizedName,
    'scope': scope.wire,
    'roleCode': roleCode?.wire,
    'congregationId': congregationId,
    'phoneE164': phoneE164,
  };
}

/// Immutable directory list state, including the URL-addressable filters (S09,
/// S10). Filters are route state so task 13 can serialise them.
class TeamQuery {
  const TeamQuery({
    this.search = '',
    this.scope,
    this.roleCode,
    this.archived = false,
    this.congregationId,
    this.cursor,
    this.limit = defaultPageSize,
  });

  final String search;
  final ContactScope? scope;
  final RoleCode? roleCode;
  final bool archived;
  final String? congregationId;
  final String? cursor;
  final int limit;

  bool get hasSearch => search.trim().isNotEmpty;

  TeamQuery copyWith({
    String? search,
    ContactScope? scope,
    bool clearScope = false,
    RoleCode? roleCode,
    bool clearRole = false,
    bool? archived,
    String? congregationId,
    bool clearCongregation = false,
    String? cursor,
    bool clearCursor = false,
    int? limit,
  }) {
    return TeamQuery(
      search: search ?? this.search,
      scope: clearScope ? null : (scope ?? this.scope),
      roleCode: clearRole ? null : (roleCode ?? this.roleCode),
      archived: archived ?? this.archived,
      congregationId: clearCongregation
          ? null
          : (congregationId ?? this.congregationId),
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      limit: limit ?? this.limit,
    );
  }

  /// Route-state representation. Values stay raw here; callers build a `Uri`
  /// (which percent-encodes accented names and spaces) when composing a URL.
  Map<String, String> toQueryParameters() {
    return <String, String>{
      if (hasSearch) 'busca': search.trim(),
      if (scope != null) 'escopo': scope!.wire,
      if (roleCode != null) 'papel': roleCode!.wire,
      if (archived) 'arquivados': '1',
      if (congregationId != null && congregationId!.isNotEmpty)
        'congregacao': congregationId!,
    };
  }

  factory TeamQuery.fromQueryParameters(Map<String, String> parameters) {
    final String? scope = parameters['escopo'];
    final String? role = parameters['papel'];
    return TeamQuery(
      search: parameters['busca'] ?? '',
      scope: scope == null || scope.isEmpty
          ? null
          : ContactScope.fromWire(scope),
      roleCode: role == null || role.isEmpty ? null : RoleCode.fromWire(role),
      archived: parameters['arquivados'] == '1',
      congregationId: parameters['congregacao'],
    );
  }
}

/// The editable contact fields for create and rename (S05, S06).
class ContactDraft {
  const ContactDraft({
    required this.name,
    required this.scope,
    this.congregationId,
    this.roleCode,
    this.phone,
    this.birthDate,
  });

  final String name;
  final ContactScope scope;
  final String? congregationId;
  final RoleCode? roleCode;
  final String? phone;
  final CalendarDate? birthDate;
}

/// The identity of a role replacement, including both revisions (S06, S11).
class RoleReplacementRequest {
  const RoleReplacementRequest({
    required this.scope,
    required this.congregationId,
    required this.roleCode,
    required this.previousContactId,
    required this.previousExpectedRevision,
    required this.targetContactId,
    required this.targetExpectedRevision,
  });

  final ContactScope scope;
  final String? congregationId;
  final RoleCode roleCode;
  final String previousContactId;
  final int previousExpectedRevision;
  final String targetContactId;
  final int targetExpectedRevision;
}

class TeamMutationResult {
  const TeamMutationResult({
    required this.id,
    required this.revision,
    this.previousContactId,
    this.previousRevision,
  });

  final String id;
  final int revision;
  final String? previousContactId;
  final int? previousRevision;

  factory TeamMutationResult.fromJson(JsonMap json) => TeamMutationResult(
    id: requireString(json, 'id'),
    revision: requireInt(json, 'revision'),
    previousContactId: optionalString(json, 'previousContactId'),
    previousRevision: json['previousRevision'] is int
        ? json['previousRevision'] as int
        : null,
  );
}

class TeamRepository {
  TeamRepository({
    required this.gateway,
    Uuid? uuid,
    this.requestIdFactory,
    this.recordIdFactory,
  }) : _uuid = uuid ?? const Uuid();

  final BackendGateway gateway;
  final Uuid _uuid;
  final String Function()? requestIdFactory;
  final String Function()? recordIdFactory;

  String newRequestId() => requestIdFactory?.call() ?? _uuid.v4();

  String newRecordId() => recordIdFactory?.call() ?? _uuid.v4();

  /// Lists active directory projections, or scoped archived contact records
  /// when [TeamQuery.archived] is set. Archived contacts have no directory
  /// projection, so that branch requires a selected congregation (S06).
  Future<PageResult> listDirectory(TeamQuery query) {
    if (query.archived) {
      return gateway.query(
        QueryRequest(
          resource: QueryResource.contacts,
          congregationId: query.congregationId,
          equalityFilters: const <String, Object?>{'archived': true},
          limit: query.limit,
          cursor: query.cursor,
        ),
      );
    }
    final Map<String, Object?> filters = <String, Object?>{};
    if (query.scope != null) {
      filters['scope'] = query.scope!.wire;
    }
    if (query.roleCode != null) {
      filters['roleCode'] = query.roleCode!.wire;
    }
    return gateway.query(
      QueryRequest(
        resource: QueryResource.directory,
        equalityFilters: filters.isEmpty ? null : filters,
        namePrefix: query.hasSearch ? query.search.trim() : null,
        limit: query.limit,
        cursor: query.cursor,
      ),
    );
  }

  /// Resolves only the directory projection, never the private record.
  Future<DirectoryEntry?> getDirectoryEntry(String id) async {
    final JsonMap? json = await gateway.get(
      RecordLocator(resource: QueryResource.directory, id: id),
    );
    return json == null ? null : DirectoryEntry.fromJson(json);
  }

  /// Reads the scoped full contact record so an authorized editor can obtain
  /// its revision. A supervision contact resolves through the top-level
  /// supervisor-protected `supervisionContacts/{id}` document; a congregation
  /// contact resolves through its scoped collection.
  Future<Contact?> getContact({
    required String id,
    required ContactScope scope,
    String? congregationId,
  }) async {
    if (scope == ContactScope.supervision) {
      final JsonMap? json = await gateway.get(
        RecordLocator(resource: QueryResource.contacts, id: id),
      );
      return json == null ? null : Contact.fromJson(json);
    }
    if (congregationId == null || congregationId.isEmpty) {
      return null;
    }
    final JsonMap? json = await gateway.get(
      RecordLocator(
        resource: QueryResource.contacts,
        id: id,
        congregationId: congregationId,
      ),
    );
    return json == null ? null : Contact.fromJson(json);
  }

  /// Returns the current holder of an administrative role within one scope,
  /// resolved from the directory projection, or `null` when the role is free.
  ///
  /// A congregation lookup is scoped in the query itself: role holders of two
  /// congregations that share the same role never leak into each other's
  /// result, and the emitted `congregationId` equality filter is bound into
  /// the cursor fingerprint. A supervision lookup carries no congregation
  /// filter because supervision role slots are global.
  ///
  /// Follow-up (backend corrective): the emitted directory shape
  /// `{scope, roleCode, congregationId}` ordered by `normalizedName` is NOT
  /// covered by the declared S09 directory indexes / `firestore.indexes.json`,
  /// which ship only `scope+normalizedName`, `scope+roleCode+normalizedName`
  /// and `congregationId+normalizedName`. A backend corrective must add the
  /// composite collection-scope index `[scope, roleCode, congregationId,
  /// normalizedName]` (all ASCENDING) to `firestore.indexes.json`, the S09
  /// query matrix and its index test. This client emits the required filter
  /// rather than falling back to an unscoped page.
  Future<DirectoryEntry?> findAdministrativeHolder({
    required ContactScope scope,
    String? congregationId,
    required RoleCode roleCode,
  }) async {
    final Map<String, Object?> filters = <String, Object?>{
      'scope': scope.wire,
      'roleCode': roleCode.wire,
    };
    if (scope == ContactScope.congregation &&
        congregationId != null &&
        congregationId.isNotEmpty) {
      filters['congregationId'] = congregationId;
    }
    final PageResult page = await gateway.query(
      QueryRequest(resource: QueryResource.directory, equalityFilters: filters),
    );
    for (final JsonMap item in page.items) {
      final DirectoryEntry entry = DirectoryEntry.fromJson(item);
      if (entry.roleCode == roleCode &&
          (scope == ContactScope.supervision ||
              entry.congregationId == congregationId)) {
        return entry;
      }
    }
    return null;
  }

  /// S06 create and rename. [id] and [expectedRevision] are the stable identity
  /// of an existing record; both absent means a create with a new UUID.
  Future<TeamMutationResult> saveContact({
    required ContactDraft draft,
    String? id,
    int? expectedRevision,
    String? requestId,
  }) async {
    final String recordId = id ?? newRecordId();
    final Map<String, Object?> payload = <String, Object?>{
      'id': recordId,
      'scope': draft.scope.wire,
      'congregationId': draft.congregationId,
      'name': draft.name.trim(),
      'roleCode': draft.roleCode?.wire,
      'phone': draft.phone,
      'birthDate': draft.birthDate?.toIso8601String(),
      'requestId': requestId ?? newRequestId(),
    };
    if (expectedRevision != null) {
      payload['expectedRevision'] = expectedRevision;
    }
    final JsonMap response = await gateway.invoke('saveContact', payload);
    return TeamMutationResult.fromJson(response);
  }

  /// S06 archive and restore by stable ID.
  Future<TeamMutationResult> setContactArchived({
    required String id,
    required ContactScope scope,
    String? congregationId,
    required bool archived,
    required int expectedRevision,
    String? requestId,
  }) async {
    final JsonMap response = await gateway.invoke(
      'setContactArchived',
      <String, Object?>{
        'id': id,
        'scope': scope.wire,
        'congregationId': congregationId,
        'archived': archived,
        'expectedRevision': expectedRevision,
        'requestId': requestId ?? newRequestId(),
      },
    );
    return TeamMutationResult.fromJson(response);
  }

  /// S06 administrative replacement. The former holder stays intact and
  /// unassigned; no delete is ever issued.
  Future<TeamMutationResult> replaceRoleHolder({
    required RoleReplacementRequest request,
    String? requestId,
  }) async {
    final JsonMap response = await gateway.invoke(
      'replaceRoleHolder',
      <String, Object?>{
        'scope': request.scope.wire,
        'congregationId': request.congregationId,
        'roleCode': request.roleCode.wire,
        'previousContactId': request.previousContactId,
        'previousExpectedRevision': request.previousExpectedRevision,
        'id': request.targetContactId,
        'expectedRevision': request.targetExpectedRevision,
        'requestId': requestId ?? newRequestId(),
      },
    );
    return TeamMutationResult.fromJson(response);
  }
}
