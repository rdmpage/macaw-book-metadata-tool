# Rod Page's Notes

Working notes accumulated while Dockerizing and testing Macaw.

## Internet Archive Identifier Generation

The IA export plugin (`plugins/export/Internet_archive.php`, line 2978) generates the identifier used at `archive.org/details/<identifier>` using the following priority:

1. **`ia_identifier` metadata field** — if set on the item, this is used as-is (sanitized to alphanumeric, underscore, hyphen). This is the recommended approach for controlling the identifier.

2. **Auto-generated** — if no `ia_identifier` is set, the identifier is built from:
   - Title (first 15 chars, stop words removed, non-alphanumeric stripped)
   - Volume number (2 chars, defaults to `00` if not set)
   - Author/creator (first 4 chars)
   - Example: a book titled "Walkerana" with no volume or author metadata becomes `walkerana00`

3. **Collision handling** — if the auto-generated identifier already exists at IA, letters are appended to make it unique.

This logic is not documented in the upstream codebase.

## MARC XML Metadata Field

When adding MARC XML to an item via the Edit page (`/main/edit`), you must type `marc_xml` into the left-hand field name input. The UI shows blank fields with no indication of what to enter — this is an upstream UX issue.

## Export Module Configuration

The `export_modules` config in `macaw.php` is **case-sensitive** and must match the plugin filename exactly. The correct value for Internet Archive is `Internet_archive` (lowercase 'a'), not `Internet_Archive`.

If `export_modules` is set to an empty array, the export cron job runs silently with no output and no errors — easy to miss.
