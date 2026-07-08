/// Which visual PDF template an invoice renders with.
///
/// Stored on the invoice itself so an already-sent invoice never changes
/// its look when the app-wide default changes.
enum InvoiceTemplateId {
  classic,
  modern,
  minimal;

  static InvoiceTemplateId fromName(String name) =>
      InvoiceTemplateId.values.firstWhere(
        (t) => t.name == name,
        orElse: () => InvoiceTemplateId.classic,
      );

  String get label => switch (this) {
    InvoiceTemplateId.classic => 'Classic',
    InvoiceTemplateId.modern => 'Modern',
    InvoiceTemplateId.minimal => 'Minimal',
  };

  String get description => switch (this) {
    InvoiceTemplateId.classic => 'Traditional ruled table',
    InvoiceTemplateId.modern => 'Color band header, airy',
    InvoiceTemplateId.minimal => 'Typographic, monochrome',
  };
}
