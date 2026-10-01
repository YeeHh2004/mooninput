# Selection research - 2026-10-02

Goal: a broadly reusable MoonBit component with a core responsibility distinct from existing ecosystem libraries.

Research checked 2,803 records returned by https://mooncakes.io/api/v0/modules, then GitHub repository and code searches for inputmask, input_mask, masked_input, maskedinput, maskito, formatted input and related terms. Metadata-only search is insufficient: MoonMoney and rename planning already have GitHub implementations despite not appearing under these descriptions in the registry snapshot.

## Closest existing work

| Project | Existing responsibility | MoonInput boundary |
| --- | --- | --- |
| [moonform](https://github.com/2d5rrr333/moonform) | Field state, dirty/touched, validation timing, submission | Editing inside one structured field: separators, raw/display values, replacement, deletion, caret mapping. Can feed raw values into moonform. |
| [string_zipper](https://github.com/moonbit-community/string_zipper) | Cursor-oriented text storage and editing | Format-constrained editing and intermediate input states. Does not replace a general text buffer. |
| [MoUI](https://github.com/wzzc-dev/MoUI) | Complete GUI framework and controls | Pure data-in/data-out input editing independent of a renderer. Searches of mask-related sources did not identify a directly equivalent input-mask engine. |
| [checkdigit](https://github.com/sssssurf/checkdigit) | Identifier/checksum validation | Input editing only; no claim of identity or payment validity. |

The earlier virtual-list candidate was rejected because MoUI already implements the same central behavior. A different package boundary alone was not sufficient differentiation.

No direct equivalent to the proposed structured input editing engine was identified in this search. This is a bounded search conclusion, not a claim of being the first or of exhaustive absence. Unindexed, private, newly published or differently described work can be missed.

## Existing demand outside MoonBit

[IMask](https://imask.js.org/guide.html) demonstrates pattern, number, date and input-selection behavior as a reusable capability across applications. MoonInput uses these general problem categories as design references, with its own smaller documented API and implementation. It is not an IMask port or a compatibility implementation. No upstream source is copied.

## Cross-domain examples

1. Contact form: paste formatted telephone text, edit the middle and submit the unformatted digits.
2. Inventory/pricing form: edit signed decimal quantities and amounts with grouping while keeping exact decimal strings.
3. Registration/appointment form: edit a date or business code, distinguish incomplete values from completed invalid dates, and submit canonical text.

The runtime needs no remote service, paid key, account, special hardware or industry-specific protocol. The main output is a reusable Mooncakes package; the website demonstrates it.
