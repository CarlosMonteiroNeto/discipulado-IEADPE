# Dependency and template decisions

The user authorized autonomous choices. Use the standard Flutter scaffold; no third-party template is adopted. Category search produced no candidate table; that does not prove no templates exist. Source fidelity favors a focused port.

- archive 4.5.2: 75 (AUTO_APPROVE).
- excel 4.0.6: 34.4 (AUTO_REJECT).
- file_picker 13.1.0: 75 (AUTO_APPROVE).
- file_saver 0.7.0: 75 (AUTO_APPROVE).
- flutter_riverpod 3.4.3: 72.5 (AUTO_APPROVE).
- go_router 18.1.0: 73.8 (AUTO_APPROVE).
- image 4.12.0: 75 (AUTO_APPROVE).
- image_picker 1.2.4: 75 (AUTO_APPROVE).
- intl 0.20.3: 67 (DEVELOPER_DECISION).
- supabase_flutter 2.18.3: 73.8 (AUTO_APPROVE).
- timezone 0.11.2: 67 (DEVELOPER_DECISION).
- url_launcher 6.3.3: 75 (AUTO_APPROVE).
- uuid 4.6.0: 75 (AUTO_APPROVE).

Reject excel (34.4); use archive/xml (75) for the narrow source XLSX format. Select intl/timezone (67) for maintained localization and Sao Paulo date support, subject to actual dependency resolution. Popularity/dependents collection is best effort; a score is not proof of compatibility. Full reports are adjacent JSON files.
