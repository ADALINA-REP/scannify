import 'package:flutter/material.dart';
import '../../features/ocr/domain/models/financial_analysis.dart';
import '../../features/receipts/domain/entities/receipt.dart';
import '../../features/receipts/domain/repositories/receipt_repository.dart';

/// Supported application languages for internationalization.
enum AppLanguage {
  automatic(
    code: 'auto',
    label: 'Automatic',
    englishName: 'System Default',
    flagEmoji: '🌐',
  ),
  english(
    code: 'en',
    label: 'English',
    englishName: 'English',
    flagEmoji: '🇬🇧',
  ),
  french(
    code: 'fr',
    label: 'Français',
    englishName: 'French',
    flagEmoji: '🇫🇷',
  ),
  german(
    code: 'de',
    label: 'Deutsch',
    englishName: 'German',
    flagEmoji: '🇩🇪',
  ),
  spanish(
    code: 'es',
    label: 'Español',
    englishName: 'Spanish',
    flagEmoji: '🇪🇸',
  ),
  italian(
    code: 'it',
    label: 'Italiano',
    englishName: 'Italian',
    flagEmoji: '🇮🇹',
  ),
  portuguese(
    code: 'pt',
    label: 'Português',
    englishName: 'Portuguese',
    flagEmoji: '🇧🇷',
  ),
  arabic(
    code: 'ar',
    label: 'العربية (RTL)',
    englishName: 'Arabic',
    flagEmoji: '🇲🇦',
  );

  const AppLanguage({
    required this.code,
    required this.label,
    required this.englishName,
    required this.flagEmoji,
  });

  final String code;
  final String label;
  final String englishName;
  final String flagEmoji;

  Locale get locale => Locale(code == 'auto' ? effectiveLanguage.code : code);

  String get localeString => switch (effectiveLanguage) {
    AppLanguage.french => 'fr_FR',
    AppLanguage.spanish => 'es_ES',
    AppLanguage.german => 'de_DE',
    AppLanguage.italian => 'it_IT',
    AppLanguage.portuguese => 'pt_PT',
    AppLanguage.arabic => 'ar_SA',
    _ => 'en_US',
  };

  AppLanguage get effectiveLanguage {
    if (this != AppLanguage.automatic) return this;
    return AppLanguage.fromSystemLocale();
  }

  static AppLanguage fromSystemLocale() {
    try {
      final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
      final code = systemLocale.languageCode.toLowerCase();
      if (code.startsWith('fr')) return AppLanguage.french;
      if (code.startsWith('es')) return AppLanguage.spanish;
      if (code.startsWith('de')) return AppLanguage.german;
      if (code.startsWith('it')) return AppLanguage.italian;
      if (code.startsWith('pt')) return AppLanguage.portuguese;
      if (code.startsWith('ar')) return AppLanguage.arabic;
    } catch (_) {}
    return AppLanguage.english;
  }

  static AppLanguage fromCode(String? code) {
    if (code == null) return AppLanguage.english;
    final lower = code.toLowerCase();
    if (lower == 'auto') return AppLanguage.automatic;
    if (lower.startsWith('fr')) return AppLanguage.french;
    if (lower.startsWith('es')) return AppLanguage.spanish;
    if (lower.startsWith('de')) return AppLanguage.german;
    if (lower.startsWith('it')) return AppLanguage.italian;
    if (lower.startsWith('pt')) return AppLanguage.portuguese;
    if (lower.startsWith('ar')) return AppLanguage.arabic;
    return AppLanguage.english;
  }
}

/// Extensible localization dictionary supporting English, French, Spanish, German, Italian, Portuguese, and Arabic.
class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;
  AppLanguage get effective => language.effectiveLanguage;

  bool get isFrench => effective == AppLanguage.french;
  bool get isSpanish => effective == AppLanguage.spanish;
  bool get isGerman => effective == AppLanguage.german;
  bool get isItalian => effective == AppLanguage.italian;
  bool get isPortuguese => effective == AppLanguage.portuguese;
  bool get isArabic => effective == AppLanguage.arabic;

  static AppStrings of(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    return AppStrings(AppLanguage.fromCode(locale?.languageCode));
  }

  // Brand & Navigation
  String get appName => 'Scannify';

  String get navDashboard => switch (effective) {
    AppLanguage.french => 'Tableau de bord',
    AppLanguage.spanish => 'Panel',
    AppLanguage.german => 'Übersicht',
    AppLanguage.italian => 'Dashboard',
    AppLanguage.portuguese => 'Painel',
    AppLanguage.arabic => 'لوحة التحكم',
    _ => 'Dashboard',
  };

  String get navHistory => switch (effective) {
    AppLanguage.french => 'Historique',
    AppLanguage.spanish => 'Historial',
    AppLanguage.german => 'Verlauf',
    AppLanguage.italian => 'Cronologia',
    AppLanguage.portuguese => 'Histórico',
    AppLanguage.arabic => 'السجل',
    _ => 'History',
  };

  String get navExport => switch (effective) {
    AppLanguage.french => 'Exporter',
    AppLanguage.spanish => 'Exportar',
    AppLanguage.german => 'Exportieren',
    AppLanguage.italian => 'Esporta',
    AppLanguage.portuguese => 'Exportar',
    AppLanguage.arabic => 'تصدير',
    _ => 'Export',
  };

  String get navSettings => switch (effective) {
    AppLanguage.french => 'Paramètres',
    AppLanguage.spanish => 'Ajustes',
    AppLanguage.german => 'Einstellungen',
    AppLanguage.italian => 'Impostazioni',
    AppLanguage.portuguese => 'Definições',
    AppLanguage.arabic => 'الإعدادات',
    _ => 'Settings',
  };

  String get scanReceiptCta => switch (effective) {
    AppLanguage.french => 'Scanner un reçu',
    AppLanguage.spanish => 'Escanear recibo',
    AppLanguage.german => 'Beleg scannen',
    AppLanguage.italian => 'Scansiona scontrino',
    AppLanguage.portuguese => 'Digitalizar recibo',
    AppLanguage.arabic => 'مسح إيصال',
    _ => 'Scan Receipt',
  };

  // Dashboard
  String get totalMonthlyExpenses => switch (effective) {
    AppLanguage.french => 'Dépenses du mois',
    AppLanguage.spanish => 'Gastos del mes',
    AppLanguage.german => 'Monatliche Ausgaben',
    AppLanguage.italian => 'Spese del mese',
    AppLanguage.portuguese => 'Despesas do mês',
    AppLanguage.arabic => 'مصاريف الشهر',
    _ => 'Monthly Expenses',
  };

  String receiptsCountLabel(int count) {
    return switch (effective) {
      AppLanguage.french => '$count ${count <= 1 ? 'reçu' : 'reçus'}',
      AppLanguage.spanish => '$count ${count == 1 ? 'recibo' : 'recibos'}',
      AppLanguage.german => '$count ${count == 1 ? 'Beleg' : 'Belege'}',
      AppLanguage.italian => '$count ${count == 1 ? 'scontrino' : 'scontrini'}',
      AppLanguage.portuguese => '$count ${count == 1 ? 'recibo' : 'recibos'}',
      AppLanguage.arabic => '$count ${count == 1 ? 'إيصال' : 'إيصالات'}',
      _ => '$count ${count == 1 ? 'receipt' : 'receipts'}',
    };
  }

  String vsPreviousMonth(String percentageText) => switch (effective) {
    AppLanguage.french => '$percentageText vs mois dernier',
    AppLanguage.spanish => '$percentageText vs mes anterior',
    AppLanguage.german => '$percentageText ggü. Vormonat',
    AppLanguage.italian => '$percentageText rispetto al mese scorso',
    AppLanguage.portuguese => '$percentageText vs mês anterior',
    AppLanguage.arabic => '$percentageText مقارنة بالشهر السابق',
    _ => '$percentageText vs last month',
  };

  String get recentTransactions => switch (effective) {
    AppLanguage.french => 'Transactions récentes',
    AppLanguage.spanish => 'Transacciones recientes',
    AppLanguage.german => 'Letzte Transaktionen',
    AppLanguage.italian => 'Transazioni recenti',
    AppLanguage.portuguese => 'Transações recentes',
    AppLanguage.arabic => 'أحدث المعاملات',
    _ => 'Recent Transactions',
  };

  String get viewAll => switch (effective) {
    AppLanguage.french => 'Tout voir',
    AppLanguage.spanish => 'Ver todo',
    AppLanguage.german => 'Alle anzeigen',
    AppLanguage.italian => 'Mostra tutto',
    AppLanguage.portuguese => 'Ver tudo',
    AppLanguage.arabic => 'عرض الكل',
    _ => 'View All',
  };

  String get emptyDashboardTitle => switch (effective) {
    AppLanguage.french => 'Aucun reçu ce mois-ci',
    AppLanguage.spanish => 'Sin recibos este mes',
    AppLanguage.german => 'Keine Belege in diesem Monat',
    AppLanguage.italian => 'Nessuno scontrino questo mese',
    AppLanguage.portuguese => 'Nenhum recibo este mês',
    AppLanguage.arabic => 'لا توجد إيصالات هذا الشهر',
    _ => 'No receipts this month',
  };

  String get emptyDashboardSubtitle => switch (effective) {
    AppLanguage.french =>
      'Scannez votre premier reçu pour suivre et catégoriser vos dépenses automatiquement.',
    AppLanguage.spanish =>
      'Escanee su primer recibo para extraer y categorizar sus gastos automáticamente.',
    AppLanguage.german =>
      'Scannen Sie Ihren ersten Beleg, um Ausgaben automatisch zu erfassen und zu kategorisieren.',
    AppLanguage.italian =>
      'Scansiona il tuo primo scontrino per estrarre e classificare le spese automaticamente.',
    AppLanguage.portuguese =>
      'Digitalize o seu primeiro recibo para extrair e controlar despesas automaticamente.',
    AppLanguage.arabic =>
      'امسح إيصالك أو فاتورتك الأولى لبدء التتبع المحاسبي والمالي التلقائي.',
    _ => 'Scan your first receipt to automatically extract and track your expenses.',
  };

  // Deductible VAT / Tax Credit Widget (P2)
  String get deductibleVatTitle => switch (effective) {
    AppLanguage.french => 'TVA DÉDUCTIBLE',
    AppLanguage.spanish => 'IVA DEDUCIBLE',
    AppLanguage.german => 'VORSTEUER / MWST',
    AppLanguage.italian => 'IVA DETRAIBILE',
    AppLanguage.portuguese => 'IVA DEDUTÍVEL',
    AppLanguage.arabic => 'الضريبة القابلة للاسترداد',
    _ => 'DEDUCTIBLE VAT',
  };

  String get taxCreditBadge => switch (effective) {
    AppLanguage.french => 'CRÉDIT FISCAL',
    AppLanguage.spanish => 'CRÉDITO FISCAL',
    AppLanguage.german => 'STEUERBONUS',
    AppLanguage.italian => 'CREDITO D\'IMPOSTA',
    AppLanguage.portuguese => 'CRÉDITO FISCAL',
    AppLanguage.arabic => 'ائتمان ضريبي',
    _ => 'TAX CREDIT',
  };

  String get deductibleVatSubtitle => switch (effective) {
    AppLanguage.french => 'TVA récupérable à déduire sur votre déclaration fiscale.',
    AppLanguage.spanish => 'Total de IVA soportado a deducir en su declaración.',
    AppLanguage.german => 'Vorsteuerabzug für Ihre Steuererklärung.',
    AppLanguage.italian => 'Totale IVA a credito da detrarre nella dichiarazione fiscale.',
    AppLanguage.portuguese => 'Total de imposto a deduzir na sua declaração fiscal.',
    AppLanguage.arabic => 'إجمالي الضريبة القابلة للاسترداد في إقرارك الضريبي القادم.',
    _ => 'Total input VAT to deduct on your tax declaration.',
  };

  String get subtotalExclTax => switch (effective) {
    AppLanguage.french => 'Sous-total HT',
    AppLanguage.spanish => 'Base imponible',
    AppLanguage.german => 'Nettobetrag (ohne MwSt)',
    AppLanguage.italian => 'Imponibile (senza IVA)',
    AppLanguage.portuguese => 'Subtotal sem imposto',
    AppLanguage.arabic => 'المجموع دون ضريبة',
    _ => 'Subtotal excl. tax',
  };

  String get totalInclTax => switch (effective) {
    AppLanguage.french => 'Total TTC',
    AppLanguage.spanish => 'Total con IVA',
    AppLanguage.german => 'Gesamtbetrag (inkl. MwSt)',
    AppLanguage.italian => 'Totale IVA inclusa',
    AppLanguage.portuguese => 'Total com imposto',
    AppLanguage.arabic => 'المجموع شامل الضريبة',
    _ => 'Total incl. tax',
  };

  String get receiptsMetricLabel => switch (effective) {
    AppLanguage.french => 'Justificatifs',
    AppLanguage.spanish => 'Comprobantes',
    AppLanguage.german => 'Belege',
    AppLanguage.italian => 'Giustificativi',
    AppLanguage.portuguese => 'Comprovativos',
    AppLanguage.arabic => 'إيصالات',
    _ => 'Receipts',
  };

  String get vatBreakdownByRate => switch (effective) {
    AppLanguage.french => 'Ventilation par taux de TVA',
    AppLanguage.spanish => 'Desglose por tipo de IVA',
    AppLanguage.german => 'MwSt-Aufschlüsselung nach Steuersatz',
    AppLanguage.italian => 'Ripartizione IVA per aliquota',
    AppLanguage.portuguese => 'Discriminação do IVA por taxa',
    AppLanguage.arabic => 'تفصيل الضريبة حسب النسبة',
    _ => 'VAT Breakdown by Rate',
  };

  String get vatExemptOrZero => switch (effective) {
    AppLanguage.french => 'Exonéré / 0%',
    AppLanguage.spanish => 'Exento / 0%',
    AppLanguage.german => 'Steuerfrei / 0%',
    AppLanguage.italian => 'Esente / 0%',
    AppLanguage.portuguese => 'Isento / 0%',
    AppLanguage.arabic => 'معفى / 0%',
    _ => 'Exempt / 0%',
  };

  String get deductibleVatFootnote => switch (effective) {
    AppLanguage.french =>
      'Montants calculés à partir de vos justificatifs pour votre déclaration de TVA.',
    AppLanguage.spanish =>
      'Importes calculados a partir de sus justificantes para su declaración tributaria.',
    AppLanguage.german =>
      'Berechnete Beträge aus Belegen zur direkten Übernahme in die Steuererklärung.',
    AppLanguage.italian =>
      'Importi calcolati dagli scontrini verificati per la dichiarazione fiscale.',
    AppLanguage.portuguese =>
      'Valores calculados com base nos comprovativos para a declaração fiscal.',
    AppLanguage.arabic =>
      'مبالغ محسوبة ومحققة من الإيصالات لإدراجها في إقرارك الضريبي.',
    _ => 'Amounts calculated from verified receipts for direct inclusion in your tax return.',
  };

  // Accounting & Tax Report (P1)
  String get accountingReportCta => switch (effective) {
    AppLanguage.french => 'Dossier Comptable PDF en 1 clic',
    AppLanguage.spanish => 'Informe Contable PDF en 1 clic',
    AppLanguage.german => '1-Klick Buchhaltungsbericht PDF',
    AppLanguage.italian => 'Report Contabile PDF in 1 clic',
    AppLanguage.portuguese => 'Relatório Contábil PDF em 1 clique',
    AppLanguage.arabic => 'تقرير محاسبي بنقرة واحدة PDF',
    _ => '1-Click Accounting Report PDF',
  };

  String get accountingReportTitle => switch (effective) {
    AppLanguage.french => 'Dossier Comptable & Fiscal',
    AppLanguage.spanish => 'Informe Contable y Fiscal',
    AppLanguage.german => 'Buchhaltungs- & Steuerbericht',
    AppLanguage.italian => 'Report Contabile e Fiscale',
    AppLanguage.portuguese => 'Relatório Contábil e Fiscal',
    AppLanguage.arabic => 'التقرير المحاسبي والضريبي',
    _ => 'Accounting & Tax Report',
  };

  String get certifiedAccountingReportSubtitle => switch (effective) {
    AppLanguage.french => 'Dossier Comptable & Fiscal Certifié',
    AppLanguage.spanish => 'Informe Contable y Fiscal Certificado',
    AppLanguage.german => 'Zertifizierter Buchhaltungs- & Steuerbericht',
    AppLanguage.italian => 'Report Contabile e Fiscale Certificato',
    AppLanguage.portuguese => 'Relatório Contábil e Fiscal Certificado',
    AppLanguage.arabic => 'تقرير محاسبي وضريبي معتمد',
    _ => 'Certified Accounting & Tax Report',
  };

  String get generatingAccountingReport => switch (effective) {
    AppLanguage.french => 'Génération du dossier comptable...',
    AppLanguage.spanish => 'Generando informe contable...',
    AppLanguage.german => 'Buchhaltungsbericht wird generiert...',
    AppLanguage.italian => 'Generazione report contabile in corso...',
    AppLanguage.portuguese => 'Gerando relatório contábil...',
    AppLanguage.arabic => 'جارٍ إنشاء التقرير المحاسبي...',
    _ => 'Generating monthly accounting report...',
  };

  String get errorGeneratingAccountingReport => switch (effective) {
    AppLanguage.french => 'Erreur lors de la génération du dossier.',
    AppLanguage.spanish => 'Error al generar el informe contable.',
    AppLanguage.german => 'Fehler beim Erstellen des Berichts.',
    AppLanguage.italian => 'Errore durante la generazione del report.',
    AppLanguage.portuguese => 'Erro ao gerar o relatório contábil.',
    AppLanguage.arabic => 'تعذر إنشاء التقرير المحاسبي.',
    _ => 'Failed to generate accounting report.',
  };

  String get attachReceiptPhotosSubtitle => switch (effective) {
    AppLanguage.french => 'Ajoute une page par justificatif photo (Dossier Comptable)',
    AppLanguage.spanish => 'Adjunta una página por comprobante (Informe Contable)',
    AppLanguage.german => 'Fügt eine Seite pro Belegfoto hinzu (Buchhaltungsbericht)',
    AppLanguage.italian => 'Allega una pagina per scontrino (Report Contabile)',
    AppLanguage.portuguese => 'Anexa uma página por foto de comprovante (Relatório Contábil)',
    AppLanguage.arabic => 'إرفاق صفحة لكل صورة إيصال (ملحق التقرير المحاسبي)',
    _ => 'Attach one page per receipt photo (Accounting Report)',
  };

  String accountingReceiptFootnote(int pieceNum) => switch (effective) {
    AppLanguage.french => 'Dossier Comptable Scannify • Pièce #$pieceNum',
    AppLanguage.spanish => 'Informe Contable Scannify • Comprobante #$pieceNum',
    AppLanguage.german => 'Scannify Buchhaltungsbericht • Beleg #$pieceNum',
    AppLanguage.italian => 'Report Contabile Scannify • Giustificativo #$pieceNum',
    AppLanguage.portuguese => 'Relatório Contábil Scannify • Comprovante #$pieceNum',
    AppLanguage.arabic => 'تقرير سكانيفاي المحاسبي • مستند #$pieceNum',
    _ => 'Scannify Accounting Report • Receipt #$pieceNum',
  };

  // Scanner & Validation
  String get scannerTitle => switch (effective) {
    AppLanguage.french => 'Acquisition de reçu',
    AppLanguage.spanish => 'Escáner de recibos',
    AppLanguage.german => 'Beleg erfassen',
    AppLanguage.italian => 'Scanner di scontrini',
    AppLanguage.portuguese => 'Digitalizar recibo',
    AppLanguage.arabic => 'الماسح الضوئي للإيصالات',
    _ => 'Receipt Scanner',
  };

  String get scannerGuidance => switch (effective) {
    AppLanguage.french => 'Placez le reçu à plat dans le cadre avec un bon éclairage',
    AppLanguage.spanish => 'Coloque el recibo plano en el marco con buena iluminación',
    AppLanguage.german => 'Platzieren Sie den Beleg flach im Rahmen mit guter Beleuchtung',
    AppLanguage.italian => 'Posiziona lo scontrino piatto nell\'inquadratura ben illuminata',
    AppLanguage.portuguese => 'Coloque o recibo plano no enquadramento com boa iluminação',
    AppLanguage.arabic => 'ضع الإيصال بشكل مستوٍ داخل الإطار مع إضاءة واضحة',
    _ => 'Align the receipt inside the frame under clear lighting',
  };

  String get capturePhoto => switch (effective) {
    AppLanguage.french => 'Prendre une photo',
    AppLanguage.spanish => 'Tomar foto',
    AppLanguage.german => 'Foto aufnehmen',
    AppLanguage.italian => 'Scatta foto',
    AppLanguage.portuguese => 'Tirar foto',
    AppLanguage.arabic => 'التقاط صورة',
    _ => 'Capture Photo',
  };

  String get importFromGallery => switch (effective) {
    AppLanguage.french => 'Importer de la galerie',
    AppLanguage.spanish => 'Importar de la galería',
    AppLanguage.german => 'Aus Galerie importieren',
    AppLanguage.italian => 'Importa dalla galleria',
    AppLanguage.portuguese => 'Importar da galeria',
    AppLanguage.arabic => 'استيراد من المعرض',
    _ => 'Import from Gallery',
  };

  String get manualEntry => switch (effective) {
    AppLanguage.french => 'Saisie manuelle',
    AppLanguage.spanish => 'Entrada manual',
    AppLanguage.german => 'Manuelle Eingabe',
    AppLanguage.italian => 'Inserimento manuale',
    AppLanguage.portuguese => 'Inserção manual',
    AppLanguage.arabic => 'إدخال يدوي',
    _ => 'Manual Entry',
  };

  String get ocrAnalyzing => switch (effective) {
    AppLanguage.french => 'Analyse locale du reçu en cours...',
    AppLanguage.spanish => 'Analizando recibo en el dispositivo...',
    AppLanguage.german => 'Beleg wird lokal auf dem Gerät analysiert...',
    AppLanguage.italian => 'Analisi dello scontrino sul dispositivo in corso...',
    AppLanguage.portuguese => 'Análise local do recibo em curso...',
    AppLanguage.arabic => 'جارٍ التحليل الذكي على جهازك...',
    _ => 'Analyzing receipt on device...',
  };

  String get validateReceiptTitle => switch (effective) {
    AppLanguage.french => 'Vérifier le reçu',
    AppLanguage.spanish => 'Validar recibo',
    AppLanguage.german => 'Beleg prüfen',
    AppLanguage.italian => 'Verifica scontrino',
    AppLanguage.portuguese => 'Validar recibo',
    AppLanguage.arabic => 'التحقق من الإيصال',
    _ => 'Validate Receipt',
  };

  String get editReceiptTitle => switch (effective) {
    AppLanguage.french => 'Modifier le reçu',
    AppLanguage.spanish => 'Editar recibo',
    AppLanguage.german => 'Beleg bearbeiten',
    AppLanguage.italian => 'Modifica scontrino',
    AppLanguage.portuguese => 'Editar recibo',
    AppLanguage.arabic => 'تعديل الإيصال',
    _ => 'Edit Receipt',
  };

  String get merchantLabel => switch (effective) {
    AppLanguage.french => 'Commerçant',
    AppLanguage.spanish => 'Comercio / Proveedor',
    AppLanguage.german => 'Händler / Aussteller',
    AppLanguage.italian => 'Fornitore',
    AppLanguage.portuguese => 'Comerciante / Fornecedor',
    AppLanguage.arabic => 'التاجر / المورد',
    _ => 'Merchant',
  };

  String get merchantHint => switch (effective) {
    AppLanguage.french => 'Nom du commerçant ou fournisseur',
    AppLanguage.spanish => 'Nombre del comercio o proveedor',
    AppLanguage.german => 'Name des Händlers oder Ausstellers',
    AppLanguage.italian => 'Nome del fornitore',
    AppLanguage.portuguese => 'Nome do comerciante ou fornecedor',
    AppLanguage.arabic => 'اسم التاجر أو الشركة الموردة',
    _ => 'Merchant or supplier name',
  };

  String get merchantRequired => switch (effective) {
    AppLanguage.french => 'Le nom du commerçant est obligatoire',
    AppLanguage.spanish => 'El nombre del comercio es obligatorio',
    AppLanguage.german => 'Händlername ist erforderlich',
    AppLanguage.italian => 'Il nome del fornitore è obbligatorio',
    AppLanguage.portuguese => 'O nome do comerciante é obrigatório',
    AppLanguage.arabic => 'اسم التاجر مطلوب',
    _ => 'Merchant name is required',
  };

  String get amountLabel => switch (effective) {
    AppLanguage.french => 'Montant TTC',
    AppLanguage.spanish => 'Importe total',
    AppLanguage.german => 'Gesamtbetrag (inkl. MwSt)',
    AppLanguage.italian => 'Importo totale',
    AppLanguage.portuguese => 'Valor total',
    AppLanguage.arabic => 'المبلغ الإجمالي',
    _ => 'Total Amount',
  };

  String get amountRequired => switch (effective) {
    AppLanguage.french => 'Veuillez saisir un montant valide (> 0)',
    AppLanguage.spanish => 'Por favor, introduzca un importe válido (> 0)',
    AppLanguage.german => 'Bitte geben Sie einen gültigen Betrag ein (> 0)',
    AppLanguage.italian => 'Inserisci un importo valido (> 0)',
    AppLanguage.portuguese => 'Por favor, insira um valor válido (> 0)',
    AppLanguage.arabic => 'يرجى إدخال مبلغ صحيح أكبر من صفر',
    _ => 'Please enter a valid amount (> 0)',
  };

  String get dateLabel => switch (effective) {
    AppLanguage.french => 'Date du reçu',
    AppLanguage.spanish => 'Fecha del recibo',
    AppLanguage.german => 'Belegdatum',
    AppLanguage.italian => 'Data scontrino',
    AppLanguage.portuguese => 'Data do recibo',
    AppLanguage.arabic => 'تاريخ الإيصال',
    _ => 'Receipt Date',
  };

  String get categoryLabel => switch (effective) {
    AppLanguage.french => 'Catégorie',
    AppLanguage.spanish => 'Categoría',
    AppLanguage.german => 'Kategorie',
    AppLanguage.italian => 'Categoria',
    AppLanguage.portuguese => 'Categoria',
    AppLanguage.arabic => 'الفئة',
    _ => 'Category',
  };

  String get invoiceNumberLabel => switch (effective) {
    AppLanguage.french => 'N° Facture / Reçu',
    AppLanguage.spanish => 'N° Factura / Recibo',
    AppLanguage.german => 'Rechnungs- / Belegnummer',
    AppLanguage.italian => 'N° Fattura / Ricevuta',
    AppLanguage.portuguese => 'N° Fatura / Recibo',
    AppLanguage.arabic => 'رقم الفاتورة / الإيصال',
    _ => 'Invoice / Receipt #',
  };

  String get saveReceipt => switch (effective) {
    AppLanguage.french => 'Enregistrer le reçu',
    AppLanguage.spanish => 'Guardar recibo',
    AppLanguage.german => 'Beleg speichern',
    AppLanguage.italian => 'Salva scontrino',
    AppLanguage.portuguese => 'Guardar recibo',
    AppLanguage.arabic => 'حفظ الإيصال',
    _ => 'Save Receipt',
  };

  String get cancel => switch (effective) {
    AppLanguage.french => 'Annuler',
    AppLanguage.spanish => 'Cancelar',
    AppLanguage.german => 'Abbrechen',
    AppLanguage.italian => 'Annulla',
    AppLanguage.portuguese => 'Cancelar',
    AppLanguage.arabic => 'إلغاء',
    _ => 'Cancel',
  };

  String get delete => switch (effective) {
    AppLanguage.french => 'Supprimer',
    AppLanguage.spanish => 'Eliminar',
    AppLanguage.german => 'Löschen',
    AppLanguage.italian => 'Elimina',
    AppLanguage.portuguese => 'Eliminar',
    AppLanguage.arabic => 'حذف',
    _ => 'Delete',
  };

  String get edit => switch (effective) {
    AppLanguage.french => 'Modifier',
    AppLanguage.spanish => 'Editar',
    AppLanguage.german => 'Bearbeiten',
    AppLanguage.italian => 'Modifica',
    AppLanguage.portuguese => 'Editar',
    AppLanguage.arabic => 'تعديل',
    _ => 'Edit',
  };

  String get retry => switch (effective) {
    AppLanguage.french => 'Réessayer',
    AppLanguage.spanish => 'Reintentar',
    AppLanguage.german => 'Wiederholen',
    AppLanguage.italian => 'Riprova',
    AppLanguage.portuguese => 'Repetir',
    AppLanguage.arabic => 'إعادة المحاولة',
    _ => 'Retry',
  };

  String get zoom => switch (effective) {
    AppLanguage.french => 'Agrandir',
    AppLanguage.spanish => 'Ampliar',
    AppLanguage.german => 'Vergrößern',
    AppLanguage.italian => 'Ingrandisci',
    AppLanguage.portuguese => 'Ampliar',
    AppLanguage.arabic => 'تكبير',
    _ => 'Zoom',
  };

  String get taxRateLabel => switch (effective) {
    AppLanguage.french => 'Taux de TVA',
    AppLanguage.spanish => 'Tipo de IVA',
    AppLanguage.german => 'Steuersatz',
    AppLanguage.italian => 'Aliquota IVA',
    AppLanguage.portuguese => 'Taxa de IVA',
    AppLanguage.arabic => 'نسبة الضريبة',
    _ => 'Tax Rate',
  };

  String get vatAmountLabel => switch (effective) {
    AppLanguage.french => 'Montant TVA',
    AppLanguage.spanish => 'Importe de IVA',
    AppLanguage.german => 'MwSt-Betrag',
    AppLanguage.italian => 'Importo IVA',
    AppLanguage.portuguese => 'Valor do IVA',
    AppLanguage.arabic => 'مبلغ الضريبة',
    _ => 'VAT Amount',
  };

  String get subtotalLabel => switch (effective) {
    AppLanguage.french => 'Sous-total HT',
    AppLanguage.spanish => 'Base imponible',
    AppLanguage.german => 'Nettobetrag',
    AppLanguage.italian => 'Imponibile',
    AppLanguage.portuguese => 'Subtotal',
    AppLanguage.arabic => 'المجموع دون ضريبة',
    _ => 'Subtotal',
  };

  String get financialValidationAlert => switch (effective) {
    AppLanguage.french => 'Avertissements de validation financière',
    AppLanguage.spanish => 'Avisos de validación financiera',
    AppLanguage.german => 'Finanzielle Validierungswarnungen',
    AppLanguage.italian => 'Avvisi di convalida finanziaria',
    AppLanguage.portuguese => 'Avisos de validação financeira',
    AppLanguage.arabic => 'تنبيهات التدقيق المالي',
    _ => 'Financial Validation Warnings',
  };

  String get allFinancialChecksPassed => switch (effective) {
    AppLanguage.french => 'Tous les contrôles comptables sont validés (HT + TVA = TTC)',
    AppLanguage.spanish => 'Todos los controles contables son válidos (Base + IVA = Total)',
    AppLanguage.german => 'Alle Buchhaltungsprüfungen bestanden (Netto + MwSt = Brutto)',
    AppLanguage.italian => 'Tutti i controlli contabili sono validi (Imponibile + IVA = Totale)',
    AppLanguage.portuguese => 'Todas as validações contábeis aprovadas (Subtotal + IVA = Total)',
    AppLanguage.arabic => 'جميع الفحوصات المحاسبية متطابقة (المجموع + الضريبة = الإجمالي)',
    _ => 'All financial arithmetic verified (Subtotal + VAT = Total)',
  };

  String get unlimitedOcrScansPro => switch (effective) {
    AppLanguage.french => 'Scans OCR illimités (Pro)',
    AppLanguage.spanish => 'Escaneos OCR ilimitados (Pro)',
    AppLanguage.german => 'Unbegrenzte OCR-Scans (Pro)',
    AppLanguage.italian => 'Scansioni OCR illimitate (Pro)',
    AppLanguage.portuguese => 'Digitalizações OCR ilimitadas (Pro)',
    AppLanguage.arabic => 'مسح ضوئي غير محدود (برو)',
    _ => 'Unlimited OCR Scans (Pro)',
  };

  String scansAvailableToday(int count) => switch (effective) {
    AppLanguage.french => '$count scan(s) disponible(s) aujourd\'hui',
    AppLanguage.spanish => '$count escaneo(s) disponible(s) hoy',
    AppLanguage.german => '$count Scan(s) heute verfügbar',
    AppLanguage.italian => '$count scansione/i disponibile/i oggi',
    AppLanguage.portuguese => '$count digitalização(ões) disponível(eis) hoje',
    AppLanguage.arabic => '$count مسح متاح اليوم',
    _ => '$count free scan(s) available today',
  };

  String get webOcrNotice => switch (effective) {
    AppLanguage.french =>
      'Sur Web, l\'OCR automatique est désactivé. Importez une image ou utilisez la saisie manuelle.',
    AppLanguage.spanish =>
      'En la Web, el OCR automático está desactivado. Importe una imagen o use la entrada manual.',
    AppLanguage.german =>
      'Im Web ist die automatische Belegerkennung deaktiviert. Bild hochladen oder manuell eingeben.',
    AppLanguage.italian =>
      'Sul Web il riconoscimento automatico è disattivato. Carica un\'immagine o inserisci manualmente.',
    AppLanguage.portuguese =>
      'Na Web, o OCR automático está desativado. Importe uma imagem ou utilize a inserção manual.',
    AppLanguage.arabic =>
      'على الويب، التعرف الضوئي التلقائي معطل. قم باستيراد صورة أو استخدم الإدخال اليدوي.',
    _ => 'On Web, automatic OCR is disabled. Import an image or use manual entry.',
  };

  String get receiptDetailsTitle => switch (effective) {
    AppLanguage.french => 'Détails du reçu',
    AppLanguage.spanish => 'Detalles del recibo',
    AppLanguage.german => 'Belegdetails',
    AppLanguage.italian => 'Dettagli scontrino',
    AppLanguage.portuguese => 'Detalhes do recibo',
    AppLanguage.arabic => 'تفاصيل الإيصال',
    _ => 'Receipt Details',
  };

  String get receiptNotFoundTitle => switch (effective) {
    AppLanguage.french => 'Reçu introuvable',
    AppLanguage.spanish => 'Recibo no encontrado',
    AppLanguage.german => 'Beleg nicht gefunden',
    AppLanguage.italian => 'Scontrino non trovato',
    AppLanguage.portuguese => 'Recibo não encontrado',
    AppLanguage.arabic => 'الإيصال غير موجود',
    _ => 'Receipt not found',
  };

  String get receiptNotFoundSubtitle => switch (effective) {
    AppLanguage.french => 'Ce reçu a été supprimé.',
    AppLanguage.spanish => 'Este recibo ha sido eliminado.',
    AppLanguage.german => 'Dieser Beleg wurde gelöscht.',
    AppLanguage.italian => 'Questo scontrino è stato eliminato.',
    AppLanguage.portuguese => 'Este recibo foi eliminado.',
    AppLanguage.arabic => 'تم حذف هذا الإيصال.',
    _ => 'This receipt has been deleted.',
  };

  String get deleteReceiptConfirmTitle => switch (effective) {
    AppLanguage.french => 'Supprimer ce reçu ?',
    AppLanguage.spanish => '¿Eliminar este recibo?',
    AppLanguage.german => 'Diesen Beleg löschen?',
    AppLanguage.italian => 'Eliminare questo scontrino?',
    AppLanguage.portuguese => 'Eliminar este recibo?',
    AppLanguage.arabic => 'هل تريد حذف هذا الإيصال؟',
    _ => 'Delete this receipt?',
  };

  String deleteReceiptConfirmMessage(String merchant) => switch (effective) {
    AppLanguage.french =>
      'Cette action supprimera définitivement le reçu "$merchant" et son image locale.',
    AppLanguage.spanish =>
      'Esta acción eliminará permanentemente el recibo "$merchant" y su imagen local.',
    AppLanguage.german =>
      'Dies löscht den Beleg "$merchant" und das gespeicherte Belegfoto unwiderruflich.',
    AppLanguage.italian =>
      'Questa azione eliminerà definitivamente lo scontrino "$merchant" e l\'immagine salvata.',
    AppLanguage.portuguese =>
      'Esta ação eliminará permanentemente o recibo "$merchant" e a sua imagem local.',
    AppLanguage.arabic =>
      'سيؤدي هذا الإجراء إلى حذف إيصال "$merchant" وصورته المحفوظة بشكل نهائي.',
    _ => 'This action will permanently delete the receipt for "$merchant" and its stored image.',
  };

  String get createdOnLabel => switch (effective) {
    AppLanguage.french => 'Ajouté le',
    AppLanguage.spanish => 'Añadido el',
    AppLanguage.german => 'Erstellt am',
    AppLanguage.italian => 'Aggiunto il',
    AppLanguage.portuguese => 'Adicionado em',
    AppLanguage.arabic => 'أضيف في',
    _ => 'Created on',
  };

  String get lastUpdatedLabel => switch (effective) {
    AppLanguage.french => 'Modifié le',
    AppLanguage.spanish => 'Modificado el',
    AppLanguage.german => 'Geändert am',
    AppLanguage.italian => 'Modificato il',
    AppLanguage.portuguese => 'Atualizado em',
    AppLanguage.arabic => 'آخر تعديل',
    _ => 'Last updated',
  };

  String get receiptImageSectionTitle => switch (effective) {
    AppLanguage.french => 'Image du reçu',
    AppLanguage.spanish => 'Imagen del recibo',
    AppLanguage.german => 'Belegfoto',
    AppLanguage.italian => 'Immagine scontrino',
    AppLanguage.portuguese => 'Imagem do recibo',
    AppLanguage.arabic => 'صورة الإيصال',
    _ => 'Receipt Image',
  };

  String get viewFullscreen => switch (effective) {
    AppLanguage.french => 'Plein écran',
    AppLanguage.spanish => 'Pantalla completa',
    AppLanguage.german => 'Vollbild',
    AppLanguage.italian => 'Schermo intero',
    AppLanguage.portuguese => 'Ecrã inteiro',
    AppLanguage.arabic => 'ملء الشاشة',
    _ => 'View Fullscreen',
  };

  String get noImageAttached => switch (effective) {
    AppLanguage.french => 'Aucune image jointe à ce reçu',
    AppLanguage.spanish => 'No hay ninguna imagen adjunta a este recibo',
    AppLanguage.german => 'Kein Belegfoto angehängt',
    AppLanguage.italian => 'Nessuna immagine allegata a questo scontrino',
    AppLanguage.portuguese => 'Nenhuma imagem anexada a este recibo',
    AppLanguage.arabic => 'لا توجد صورة مرفقة بهذا الإيصال',
    _ => 'No image attached to this receipt',
  };

  String get estimatedBadge => switch (effective) {
    AppLanguage.french => 'estimée',
    AppLanguage.spanish => 'estimado',
    AppLanguage.german => 'geschätzt',
    AppLanguage.italian => 'stimata',
    AppLanguage.portuguese => 'estimada',
    AppLanguage.arabic => 'تقديرية',
    _ => 'est.',
  };

  String get proDesignedForSubtitle => switch (effective) {
    AppLanguage.french => 'Conçu pour les freelances, indépendants et entrepreneurs',
    AppLanguage.spanish => 'Diseñado para profesionales independientes, autónomos y pymes',
    AppLanguage.german => 'Entwickelt für Freiberufler, Selbstständige und Kleinunternehmen',
    AppLanguage.italian => 'Pensato per liberi professionisti, autonomi e piccole imprese',
    AppLanguage.portuguese => 'Criado para freelancers, profissionais liberais e empreendedores',
    AppLanguage.arabic => 'مصمم للمستقلين وأصحاب الأعمال والمشاريع الصغيرة',
    _ => 'Designed for freelancers, independents, and small businesses',
  };

  List<String> get proBenefits => switch (effective) {
    AppLanguage.french => const <String>[
      'Scans OCR automatiques illimités chaque jour',
      'Exports CSV et PDF instantanés sans publicité',
      'Statistiques financières et analyses avancées',
      'Expérience 100 % sans publicité',
      'Traitement local ultra-rapide et confidentiel',
    ],
    AppLanguage.spanish => const <String>[
      'Escaneos OCR automáticos ilimitados cada día',
      'Exportaciones CSV y PDF instantáneas sin anuncios',
      'Estadísticas financieras y análisis avanzados',
      'Experiencia 100% libre de anuncios',
      'Procesamiento local ultrarrápido y privado',
    ],
    AppLanguage.german => const <String>[
      'Unbegrenzte automatische OCR-Scans jeden Tag',
      'Sofortiger CSV- & PDF-Finanzexport ohne Werbung',
      'Erweiterte Ausgabenstatistiken & Kategorie-Analysen',
      '100% werbefreie Erfahrung in der gesamten App',
      'Lokale Belegverarbeitung auf dem Gerät mit Datenschutz',
    ],
    AppLanguage.italian => const <String>[
      'Scansioni OCR automatiche illimitate ogni giorno',
      'Esportazioni CSV e PDF istantanee senza pubblicità',
      'Statistiche avanzate e analisi di spesa dettagliate',
      'Esperienza al 100% priva di annunci',
      'Elaborazione sul dispositivo locale e riservata',
    ],
    AppLanguage.portuguese => const <String>[
      'Digitalizações OCR automáticas ilimitadas todos os dias',
      'Exportações CSV e PDF instantâneas sem publicidade',
      'Estatísticas financeiras e análises avançadas de despesas',
      'Experiência 100% sem anúncios',
      'Processamento local ultra-rápido no dispositivo com privacidade',
    ],
    AppLanguage.arabic => const <String>[
      'مسح ذكي تلقائي غير محدود كل يوم',
      'تصدير تقارير CSV و PDF فورية بدون إعلانات',
      'إحصائيات مالية متقدمة وتحليلات ذكية للمصاريف',
      'تجربة خالية تماماً من الإعلانات 100%',
      'معالجة محلية فائقة السرعة مع خصوصية تامة على جهازك',
    ],
    _ => const <String>[
      'Unlimited daily automatic OCR receipt scans',
      'Instant CSV & PDF financial exports without ads',
      'Advanced expense statistics & category analytics',
      '100% ad-free experience across the app',
      '100% local on-device processing & privacy',
    ],
  };

  String get storeSubscriptionsTitle => switch (effective) {
    AppLanguage.french => 'Abonnements Google Play & App Store',
    AppLanguage.spanish => 'Suscripciones Google Play y App Store',
    AppLanguage.german => 'Google Play & App Store Abonnements',
    AppLanguage.italian => 'Abbonamenti Google Play e App Store',
    AppLanguage.portuguese => 'Assinaturas Google Play e App Store',
    AppLanguage.arabic => 'اشتراكات متجر Google Play و App Store',
    _ => 'Google Play & App Store Subscriptions',
  };

  String get storeSubscriptionsBody => switch (effective) {
    AppLanguage.french =>
      'Les achats intégrés officiels seront activés lors de la publication sur Google Play et l\'Apple App Store. En attendant, vous disposez de 3 scans gratuits par jour et du déblocage par vidéo récompensée.',
    AppLanguage.spanish =>
      'Las compras oficiales se activarán con el lanzamiento en Google Play y App Store. Mientras tanto, disfrute de 3 escaneos diarios gratuitos y desbloqueo mediante vídeo con recompensa.',
    AppLanguage.german =>
      'Offizielle Abonnements werden bei Veröffentlichung im Google Play Store freigeschaltet. Bis dahin stehen Ihnen 3 tägliche Gratis-Scans und Belohnungsvideos zur Verfügung.',
    AppLanguage.italian =>
      'Gli acquisti in-app saranno attivati al rilascio ufficiale su Google Play e App Store. Nel frattempo hai 3 scansioni gratuite al giorno e sblocchi con annunci premio.',
    AppLanguage.portuguese =>
      'As compras oficiais na aplicação serão ativadas com o lançamento na Google Play e App Store. Enquanto isso, tem 3 digitalizações grátis por dia e bónus por vídeo premiado.',
    AppLanguage.arabic =>
      'سيتم تفعيل الاشتراكات الرسمية عبر متجر Google Play عند الإطلاق الرسمي. في هذه الأثناء، استمتع بـ 3 عمليات مسح يومية مجانية وإمكانية الفتح عبر إعلانات الفيديو.',
    _ =>
      'Official store subscriptions are managed through Google Play Billing upon store release. Enjoy 3 daily free scans and rewarded video unlocks.',
  };

  String get restoreEntitlementsSuccess => switch (effective) {
    AppLanguage.french => 'Statut des droits synchronisé.',
    AppLanguage.spanish => 'Estado de suscripciones sincronizado.',
    AppLanguage.german => 'Abonnementstatus erfolgreich synchronisiert.',
    AppLanguage.italian => 'Stato degli abbonamenti sincronizzato.',
    AppLanguage.portuguese => 'Estado das assinaturas sincronizado.',
    AppLanguage.arabic => 'تمت مزامنة حالة الاشتراك بنجاح.',
    _ => 'Subscription entitlements refreshed.',
  };

  String get restoreEntitlementsCta => switch (effective) {
    AppLanguage.french => 'Actualiser le statut d\'abonnement',
    AppLanguage.spanish => 'Actualizar estado de suscripción',
    AppLanguage.german => 'Abonnementstatus aktualisieren',
    AppLanguage.italian => 'Aggiorna stato abbonamento',
    AppLanguage.portuguese => 'Atualizar estado da assinatura',
    AppLanguage.arabic => 'تحديث حالة الاشتراك',
    _ => 'Restore / Refresh Entitlements',
  };

  // Quota & Rewarded Ads
  String get watchVideo => switch (effective) {
    AppLanguage.french => 'Regarder la vidéo',
    AppLanguage.spanish => 'Ver vídeo',
    AppLanguage.german => 'Video ansehen',
    AppLanguage.italian => 'Guarda video',
    AppLanguage.portuguese => 'Assistir vídeo',
    AppLanguage.arabic => 'مشاهدة فيديو',
    _ => 'Watch Video',
  };

  String get maybeLater => switch (effective) {
    AppLanguage.french => 'Plus tard',
    AppLanguage.spanish => 'Más tarde',
    AppLanguage.german => 'Später',
    AppLanguage.italian => 'Più tardi',
    AppLanguage.portuguese => 'Mais tarde',
    AppLanguage.arabic => 'لاحقاً',
    _ => 'Maybe Later',
  };

  String get quotaExhaustedTitle => switch (effective) {
    AppLanguage.french => 'Quota quotidien atteint',
    AppLanguage.spanish => 'Límite diario alcanzado',
    AppLanguage.german => 'Tageskontingent erreicht',
    AppLanguage.italian => 'Quota giornaliera raggiunta',
    AppLanguage.portuguese => 'Limite diário atingido',
    AppLanguage.arabic => 'تم بلوغ الحد اليومي',
    _ => 'Daily Free Scans Used',
  };

  String get quotaExhaustedBody => switch (effective) {
    AppLanguage.french =>
      "Vous avez utilisé vos 3 scans gratuits d'aujourd'hui. Regardez une courte vidéo pour débloquer un scan supplémentaire.",
    AppLanguage.spanish =>
      "Ha utilizado sus 3 escaneos gratuitos de hoy. Vea un vídeo corto para desbloquear un escaneo adicional.",
    AppLanguage.german =>
      "Sie haben Ihre 3 kostenlosen Scans für heute verbraucht. Sehen Sie sich ein kurzes Video an, um einen weiteren Scan freizuschalten.",
    AppLanguage.italian =>
      "Hai utilizzato le 3 scansioni gratuite di oggi. Guarda un breve video per sbloccare una scansione aggiuntiva.",
    AppLanguage.portuguese =>
      "Você utilizou suas 3 digitalizações gratuitas de hoje. Assista a um breve vídeo para desbloquear uma digitalização extra.",
    AppLanguage.arabic =>
      "لقد استهلكت عمليات المسح الـ 3 المجانية لليوم. شاهد فيديو قصير للحصول على مسح إضافي.",
    _ => "You've used your 3 free scans for today. Watch a short video to unlock one additional scan.",
  };

  String get exportRewardTitle => switch (effective) {
    AppLanguage.french => 'Débloquer votre export',
    AppLanguage.spanish => 'Desbloquear exportación',
    AppLanguage.german => 'Export freischalten',
    AppLanguage.italian => 'Sblocca esportazione',
    AppLanguage.portuguese => 'Desbloquear exportação',
    AppLanguage.arabic => 'فتح تصدير التقارير',
    _ => 'Unlock Report Export',
  };

  String get exportRewardBody => switch (effective) {
    AppLanguage.french =>
      'Regardez une courte vidéo pour générer et partager votre rapport financier CSV ou PDF.',
    AppLanguage.spanish =>
      'Vea un vídeo corto para generar y compartir su informe financiero en CSV o PDF.',
    AppLanguage.german =>
      'Sehen Sie sich ein kurzes Video an, um Ihren Finanzbericht im CSV- oder PDF-Format zu exportieren.',
    AppLanguage.italian =>
      'Guarda un breve video per generare e condividere il tuo report finanziario CSV o PDF.',
    AppLanguage.portuguese =>
      'Assista a um breve vídeo para gerar e partilhar o seu relatório financeiro em CSV ou PDF.',
    AppLanguage.arabic =>
      'شاهد فيديو قصير لإنشاء ومشاركة تقريرك المالي بصيغة CSV أو PDF.',
    _ => 'Watch a short video to generate and share your CSV or PDF financial report.',
  };

  // Settings
  String get dailyQuotaTitle => switch (effective) {
    AppLanguage.french => 'Quota quotidien & Formule',
    AppLanguage.spanish => 'Cuota diaria y Plan',
    AppLanguage.german => 'Tageskontingent & Tarif',
    AppLanguage.italian => 'Quota giornaliera e Piano',
    AppLanguage.portuguese => 'Cota diária e Plano',
    AppLanguage.arabic => 'الحصة اليومية والاشتراك',
    _ => 'Daily Quota & Plan',
  };

  String get automaticOcrScans => switch (effective) {
    AppLanguage.french => 'Scans OCR automatiques',
    AppLanguage.spanish => 'Escaneos OCR automáticos',
    AppLanguage.german => 'Automatische OCR-Scans',
    AppLanguage.italian => 'Scansioni OCR automatiche',
    AppLanguage.portuguese => 'Digitalizações OCR automáticas',
    AppLanguage.arabic => 'عمليات المسح الضوئي التلقائية',
    _ => 'Automatic OCR Scans',
  };

  String get freeScansResetSubtitle => switch (effective) {
    AppLanguage.french =>
      '3 scans gratuits chaque jour (réinitialisés à minuit heure locale).',
    AppLanguage.spanish =>
      '3 escaneos gratuitos cada día (se reinicia a medianoche).',
    AppLanguage.german =>
      '3 kostenlose Scans pro Tag (wird um Mitternacht zurückgesetzt).',
    AppLanguage.italian =>
      '3 scansioni gratuite ogni giorno (si azzera a mezzanotte).',
    AppLanguage.portuguese =>
      '3 digitalizações gratuitas por dia (reinicia à meia-noite).',
    AppLanguage.arabic =>
      '3 عمليات مسح مجانية يومياً (تتجدد تلقائياً عند منتصف الليل).',
    _ => '3 free automatic scans every day (resets at local midnight).',
  };

  String get plusOneScanAd => switch (effective) {
    AppLanguage.french => '+1 Scan (Vidéo)',
    AppLanguage.spanish => '+1 Escaneo (Anuncio)',
    AppLanguage.german => '+1 Scan (Video)',
    AppLanguage.italian => '+1 Scansione (Video)',
    AppLanguage.portuguese => '+1 Digitalização (Vídeo)',
    AppLanguage.arabic => '+1 مسح (إعلان)',
    _ => '+1 Scan (Watch Ad)',
  };

  String get appearanceTitle => switch (effective) {
    AppLanguage.french => 'Apparence',
    AppLanguage.spanish => 'Apariencia',
    AppLanguage.german => 'Erscheinungsbild',
    AppLanguage.italian => 'Aspetto',
    AppLanguage.portuguese => 'Aparência',
    AppLanguage.arabic => 'المظهر',
    _ => 'Appearance',
  };

  String get themeDark => switch (effective) {
    AppLanguage.french => 'Mode Sombre (Signature)',
    AppLanguage.spanish => 'Modo Oscuro (Predeterminado)',
    AppLanguage.german => 'Dunkelmodus (Standard)',
    AppLanguage.italian => 'Modalità Scura (Predefinita)',
    AppLanguage.portuguese => 'Modo Escuro (Padrão)',
    AppLanguage.arabic => 'الوضع الداكن (افتراضي)',
    _ => 'Dark Mode (Default)',
  };

  String get themeLight => switch (effective) {
    AppLanguage.french => 'Mode Clair',
    AppLanguage.spanish => 'Modo Claro',
    AppLanguage.german => 'Hellmodus',
    AppLanguage.italian => 'Modalità Chiara',
    AppLanguage.portuguese => 'Modo Claro',
    AppLanguage.arabic => 'الوضع الفاتح',
    _ => 'Light Mode',
  };

  String get themeSystem => switch (effective) {
    AppLanguage.french => 'Système par défaut',
    AppLanguage.spanish => 'Predeterminado del sistema',
    AppLanguage.german => 'Systemstandard',
    AppLanguage.italian => 'Predefinito di sistema',
    AppLanguage.portuguese => 'Padrão do sistema',
    AppLanguage.arabic => 'افتراضي النظام',
    _ => 'System Default',
  };

  String get currencyAndLanguageTitle => switch (effective) {
    AppLanguage.french => 'Devise & Langue',
    AppLanguage.spanish => 'Moneda e Idioma',
    AppLanguage.german => 'Währung & Sprache',
    AppLanguage.italian => 'Valuta e Lingua',
    AppLanguage.portuguese => 'Moeda e Idioma',
    AppLanguage.arabic => 'العملة واللغة',
    _ => 'Currency & Language',
  };

  String get primaryCurrencyTitle => switch (effective) {
    AppLanguage.french => 'Devise principale',
    AppLanguage.spanish => 'Moneda principal',
    AppLanguage.german => 'Hauptwährung',
    AppLanguage.italian => 'Valuta principale',
    AppLanguage.portuguese => 'Moeda principal',
    AppLanguage.arabic => 'العملة الأساسية',
    _ => 'Primary Currency',
  };

  String get applicationLanguageTitle => switch (effective) {
    AppLanguage.french => 'Langue de l\'application',
    AppLanguage.spanish => 'Idioma de la aplicación',
    AppLanguage.german => 'App-Sprache',
    AppLanguage.italian => 'Lingua dell\'applicazione',
    AppLanguage.portuguese => 'Idioma do aplicativo',
    AppLanguage.arabic => 'لغة التطبيق',
    _ => 'Application Language',
  };

  String get languageSheetTitle => switch (effective) {
    AppLanguage.french => 'Langue',
    AppLanguage.spanish => 'Idioma',
    AppLanguage.german => 'Sprache',
    AppLanguage.italian => 'Lingua',
    AppLanguage.portuguese => 'Idioma',
    AppLanguage.arabic => 'اللغة',
    _ => 'Language',
  };

  String get privacyAndAboutTitle => switch (effective) {
    AppLanguage.french => 'Confidentialité & À propos',
    AppLanguage.spanish => 'Privacidad e Información',
    AppLanguage.german => 'Datenschutz & Info',
    AppLanguage.italian => 'Privacy e Informazioni',
    AppLanguage.portuguese => 'Privacidade e Sobre',
    AppLanguage.arabic => 'الخصوصية وعن التطبيق',
    _ => 'Privacy & About',
  };

  String get privacyPolicyTitle => switch (effective) {
    AppLanguage.french => 'Politique de confidentialité (Zéro backend)',
    AppLanguage.spanish => 'Política de Privacidad (Cero Backend)',
    AppLanguage.german => 'Datenschutzerklärung (Kein Backend)',
    AppLanguage.italian => 'Informativa sulla Privacy (Zero Backend)',
    AppLanguage.portuguese => 'Política de Privacidade (Zero Backend)',
    AppLanguage.arabic => 'سياسة الخصوصية (بدون خوادم)',
    _ => 'Privacy Policy (Zero Backend)',
  };

  String get privacyPolicySubtitle => switch (effective) {
    AppLanguage.french => 'Traitement 100% sur l\'appareil & zéro traqueur',
    AppLanguage.spanish => 'OCR 100% en el dispositivo y sin rastreadores',
    AppLanguage.german => '100% lokale Texterkennung & keine Tracker',
    AppLanguage.italian => 'OCR 100% sul dispositivo & zero tracciamento',
    AppLanguage.portuguese => 'OCR 100% no dispositivo e zero rastreadores',
    AppLanguage.arabic => 'معالجة محلية 100% على الجهاز وبدون أي تتبع',
    _ => '100% on-device OCR & zero tracking',
  };

  String get deleteAllDataTitle => switch (effective) {
    AppLanguage.french => 'Supprimer toutes les données locales',
    AppLanguage.spanish => 'Eliminar todos los datos locales',
    AppLanguage.german => 'Alle lokalen Daten löschen',
    AppLanguage.italian => 'Elimina tutti i dati locali',
    AppLanguage.portuguese => 'Eliminar todos os dados locais',
    AppLanguage.arabic => 'حذف جميع البيانات المحلية',
    _ => 'Delete All Local Data',
  };

  String get deleteAllDataSubtitle => switch (effective) {
    AppLanguage.french => 'Effacer définitivement tous les reçus et images enregistrées',
    AppLanguage.spanish => 'Borrar permanentemente todos los recibos e imágenes',
    AppLanguage.german => 'Alle Belege und gespeicherten Bilder unwiderruflich löschen',
    AppLanguage.italian => 'Elimina definitivamente tutti gli scontrini e le immagini',
    AppLanguage.portuguese => 'Apagar definitivamente todos os recibos e imagens',
    AppLanguage.arabic => 'مسح نهائي لجميع الإيصالات والصور المحفوظة',
    _ => 'Permanently erase all receipts and stored images',
  };

  String get deleteConfirmTitle => switch (effective) {
    AppLanguage.french => 'Supprimer toutes les données ?',
    AppLanguage.spanish => '¿Eliminar todos los datos locales?',
    AppLanguage.german => 'Alle lokalen Daten löschen?',
    AppLanguage.italian => 'Eliminare tutti i dati locali?',
    AppLanguage.portuguese => 'Eliminar todos os dados locais?',
    AppLanguage.arabic => 'حذف جميع البيانات المحلية؟',
    _ => 'Delete all local data?',
  };

  String get deleteConfirmMessage => switch (effective) {
    AppLanguage.french =>
      'Tous vos reçus enregistrés et leurs images associées seront définitivement effacés de cet appareil. Cette action est irréversible.',
    AppLanguage.spanish =>
      'Todos los recibos guardados y sus imágenes se eliminarán permanentemente de este dispositivo. Esta acción no se puede deshacer.',
    AppLanguage.german =>
      'Alle auf diesem Gerät gespeicherten Belege und Bilder werden unwiderruflich gelöscht. Dies kann nicht rückgängig gemacht werden.',
    AppLanguage.italian =>
      'Tutti gli scontrini e le relative immagini salvate su questo dispositivo verranno eliminati definitivamente. Questa operazione non può essere annullata.',
    AppLanguage.portuguese =>
      'Todos os recibos guardados e suas imagens serão eliminados permanentemente deste dispositivo. Esta ação não pode ser desfeita.',
    AppLanguage.arabic =>
      'سيتم مسح جميع الإيصالات والصور المحفوظة على هذا الجهاز نهائياً. لا يمكن التراجع عن هذا الإجراء.',
    _ =>
      'All locally saved receipts and their associated images will be permanently erased from this device. This action cannot be undone.',
  };

  String get deleteAllConfirmCta => switch (effective) {
    AppLanguage.french => 'Tout effacer',
    AppLanguage.spanish => 'Borrar todo',
    AppLanguage.german => 'Alles löschen',
    AppLanguage.italian => 'Cancella tutto',
    AppLanguage.portuguese => 'Apagar tudo',
    AppLanguage.arabic => 'مسح الكل',
    _ => 'Delete Everything',
  };

  String get allDataDeletedSuccess => switch (effective) {
    AppLanguage.french => 'Toutes les données locales ont été supprimées.',
    AppLanguage.spanish => 'Se han eliminado todos los datos locales.',
    AppLanguage.german => 'Alle lokalen Daten wurden gelöscht.',
    AppLanguage.italian => 'Tutti i dati locali sono stati eliminati.',
    AppLanguage.portuguese => 'Todos os dados locais foram apagados.',
    AppLanguage.arabic => 'تم حذف جميع البيانات المحلية بنجاح.',
    _ => 'All local receipt data has been erased.',
  };

  String get bonusScanUnlockedSuccess => switch (effective) {
    AppLanguage.french => '+1 scan OCR supplémentaire débloqué !',
    AppLanguage.spanish => '¡+1 escaneo OCR adicional desbloqueado!',
    AppLanguage.german => '+1 zusätzlicher OCR-Scan freigeschaltet!',
    AppLanguage.italian => '+1 scansione OCR extra sbloccata!',
    AppLanguage.portuguese => '+1 digitalização OCR adicional desbloqueada!',
    AppLanguage.arabic => 'تم فتح مسح ضوئي إضافي بنجاح!',
    _ => '+1 bonus OCR scan unlocked!',
  };

  String get appDescription => switch (effective) {
    AppLanguage.french => 'Scanner intelligent de reçus & gestionnaire de dépenses',
    AppLanguage.spanish => 'Escáner inteligente de facturas y control de gastos',
    AppLanguage.german => 'Intelligenter Belegscanner & Ausgabenmanager',
    AppLanguage.italian => 'Scanner scontrini intelligente e gestione spese',
    AppLanguage.portuguese => 'Scanner de recibos inteligente e gestor de despesas',
    AppLanguage.arabic => 'ماسح إيصالات ذكي ومتتبع للمصاريف',
    _ => 'AI Receipt Scanner & Smart Expense Tracker',
  };

  // Export Screen
  String get reportingPeriod => switch (effective) {
    AppLanguage.french => 'Période du rapport',
    AppLanguage.spanish => 'Período del informe',
    AppLanguage.german => 'Berichtszeitraum',
    AppLanguage.italian => 'Periodo del report',
    AppLanguage.portuguese => 'Período do relatório',
    AppLanguage.arabic => 'فترة التقرير',
    _ => 'Reporting Period',
  };

  String get periodCurrentMonth => switch (effective) {
    AppLanguage.french => 'Mois en cours',
    AppLanguage.spanish => 'Mes actual',
    AppLanguage.german => 'Aktueller Monat',
    AppLanguage.italian => 'Mese corrente',
    AppLanguage.portuguese => 'Mês atual',
    AppLanguage.arabic => 'الشهر الحالي',
    _ => 'Current Month',
  };

  String get periodPreviousMonth => switch (effective) {
    AppLanguage.french => 'Mois précédent',
    AppLanguage.spanish => 'Mes anterior',
    AppLanguage.german => 'Vormonat',
    AppLanguage.italian => 'Mese precedente',
    AppLanguage.portuguese => 'Mês anterior',
    AppLanguage.arabic => 'الشهر السابق',
    _ => 'Previous Month',
  };

  String get periodCurrentYear => switch (effective) {
    AppLanguage.french => 'Année en cours',
    AppLanguage.spanish => 'Año actual',
    AppLanguage.german => 'Aktuelles Jahr',
    AppLanguage.italian => 'Anno corrente',
    AppLanguage.portuguese => 'Ano atual',
    AppLanguage.arabic => 'السنة الحالية',
    _ => 'Current Year',
  };

  String get periodAllReceipts => switch (effective) {
    AppLanguage.french => 'Tous les reçus',
    AppLanguage.spanish => 'Todos los recibos',
    AppLanguage.german => 'Alle Belege',
    AppLanguage.italian => 'Tutti gli scontrini',
    AppLanguage.portuguese => 'Todos os recibos',
    AppLanguage.arabic => 'جميع الإيصالات',
    _ => 'All Receipts',
  };

  String get exportFormat => switch (effective) {
    AppLanguage.french => 'Format d\'export',
    AppLanguage.spanish => 'Formato de exportación',
    AppLanguage.german => 'Exportformat',
    AppLanguage.italian => 'Formato di esportazione',
    AppLanguage.portuguese => 'Formato de exportação',
    AppLanguage.arabic => 'صيغة التصدير',
    _ => 'Export Format',
  };

  String get pdfReportOptionTitle => switch (effective) {
    AppLanguage.french => 'Rapport PDF',
    AppLanguage.spanish => 'Informe PDF',
    AppLanguage.german => 'PDF-Bericht',
    AppLanguage.italian => 'Report PDF',
    AppLanguage.portuguese => 'Relatório PDF',
    AppLanguage.arabic => 'تقرير PDF',
    _ => 'PDF Report',
  };

  String get csvReportOptionTitle => switch (effective) {
    AppLanguage.french => 'Tableur CSV',
    AppLanguage.spanish => 'Hoja CSV',
    AppLanguage.german => 'CSV-Tabelle',
    AppLanguage.italian => 'Foglio CSV',
    AppLanguage.portuguese => 'Planilha CSV',
    AppLanguage.arabic => 'جدول CSV',
    _ => 'CSV Spreadsheet',
  };

  String get pdfReportOptionSubtitle => switch (effective) {
    AppLanguage.french =>
      'Comprend la synthèse, la ventilation fiscale et les photos des reçus en annexes',
    AppLanguage.spanish =>
      'Incluye resumen ejecutivo, desglose de impuestos y fotos de comprobantes adjuntas',
    AppLanguage.german =>
      'Enthält Zusammenfassung, Steueraufschlüsselung und Belegfotos im Anhang',
    AppLanguage.italian =>
      'Include riepilogo, ripartizione fiscale e foto degli scontrini allegate',
    AppLanguage.portuguese =>
      'Inclui resumo, detalhamento fiscal e fotos dos comprovativos em anexo',
    AppLanguage.arabic =>
      'يتضمن ملخصاً تنفيذياً، تفصيل الضرائب ومرفقات صور الإيصالات',
    _ => 'Includes executive summary, deductible tax breakdown & high-res receipt attachments',
  };

  String get csvReportOptionSubtitle => switch (effective) {
    AppLanguage.french =>
      'Grand livre tabulaire compatible avec Excel, Google Sheets et logiciels comptables',
    AppLanguage.spanish =>
      'Libro tabular compatible con Excel, Google Sheets y software contable',
    AppLanguage.german =>
      'Tabelle kompatibel mit Excel, Google Sheets, DATEV und Buchhaltungssoftware',
    AppLanguage.italian =>
      'Tabella compatibile con Excel, Google Sheets e software contabili',
    AppLanguage.portuguese =>
      'Tabela compatível com Excel, Google Sheets e softwares de contabilidade',
    AppLanguage.arabic =>
      'جدول بيانات متوافق مع Excel و Google Sheets وبرامج المحاسبة',
    _ => 'Raw tabular ledger compatible with Excel, Google Sheets, QuickBooks and Xero',
  };

  String get reportPreview => switch (effective) {
    AppLanguage.french => 'Aperçu du rapport',
    AppLanguage.spanish => 'Vista previa del informe',
    AppLanguage.german => 'Berichtsvorschau',
    AppLanguage.italian => 'Anteprima report',
    AppLanguage.portuguese => 'Pré-visualização do relatório',
    AppLanguage.arabic => 'معاينة التقرير',
    _ => 'Report Preview',
  };

  String get totalAmountMetric => switch (effective) {
    AppLanguage.french => 'TOTAL TTC',
    AppLanguage.spanish => 'TOTAL CON IVA',
    AppLanguage.german => 'GESAMTBETRAG',
    AppLanguage.italian => 'TOTALE',
    AppLanguage.portuguese => 'TOTAL',
    AppLanguage.arabic => 'المجموع الإجمالي',
    _ => 'TOTAL AMOUNT',
  };

  String get receiptsMetric => switch (effective) {
    AppLanguage.french => 'REÇUS INCLUS',
    AppLanguage.spanish => 'RECIBOS',
    AppLanguage.german => 'BELEGE',
    AppLanguage.italian => 'SCONTRINI',
    AppLanguage.portuguese => 'RECIBOS',
    AppLanguage.arabic => 'الإيصالات المشمولة',
    _ => 'RECEIPTS',
  };

  String get noReceiptsForPeriod => switch (effective) {
    AppLanguage.french => 'Aucun reçu enregistré sur cette période',
    AppLanguage.spanish => 'No hay recibos registrados en este período',
    AppLanguage.german => 'Keine Belege für diesen Zeitraum vorhanden',
    AppLanguage.italian => 'Nessuno scontrino registrato per questo periodo',
    AppLanguage.portuguese => 'Nenhum recibo registado neste período',
    AppLanguage.arabic => 'لا توجد إيصالات مسجلة لهذه الفترة',
    _ => 'No receipts recorded for this period',
  };

  String get generatePdfCta => switch (effective) {
    AppLanguage.french => 'Générer le Dossier Comptable PDF',
    AppLanguage.spanish => 'Generar Informe Contable PDF',
    AppLanguage.german => 'Buchhaltungsbericht als PDF erstellen',
    AppLanguage.italian => 'Genera Report Contabile PDF',
    AppLanguage.portuguese => 'Gerar Relatório Contábil em PDF',
    AppLanguage.arabic => 'إنشاء الحزمة المحاسبية PDF',
    _ => 'Generate PDF Accounting Package',
  };

  String get generateCsvCta => switch (effective) {
    AppLanguage.french => 'Générer le Fichier CSV',
    AppLanguage.spanish => 'Generar Archivo CSV',
    AppLanguage.german => 'CSV-Tabelle erstellen',
    AppLanguage.italian => 'Genera Foglio CSV',
    AppLanguage.portuguese => 'Gerar Folha de Cálculo CSV',
    AppLanguage.arabic => 'إنشاء جدول بيانات CSV',
    _ => 'Generate CSV Spreadsheet',
  };

  // Search & History
  String get searchHint => switch (effective) {
    AppLanguage.french => 'Rechercher par commerçant ou n° facture...',
    AppLanguage.spanish => 'Buscar por comercio o n° factura...',
    AppLanguage.german => 'Nach Händler oder Rechnungsnummer suchen...',
    AppLanguage.italian => 'Cerca per fornitore o n° fattura...',
    AppLanguage.portuguese => 'Pesquisar por comerciante ou n° fatura...',
    AppLanguage.arabic => 'بحث باسم التاجر أو رقم الفاتورة...',
    _ => 'Search by merchant or invoice #...',
  };

  String get allCategoriesLabel => switch (effective) {
    AppLanguage.french => 'Toutes',
    AppLanguage.spanish => 'Todas',
    AppLanguage.german => 'Alle',
    AppLanguage.italian => 'Tutte',
    AppLanguage.portuguese => 'Todas',
    AppLanguage.arabic => 'الكل',
    _ => 'All',
  };

  String get noReceiptsMatching => switch (effective) {
    AppLanguage.french => 'Aucun reçu ne correspond à vos filtres',
    AppLanguage.spanish => 'Ningún recibo coincide con los filtros',
    AppLanguage.german => 'Keine passenden Belege gefunden',
    AppLanguage.italian => 'Nessuno scontrino corrisponde ai filtri',
    AppLanguage.portuguese => 'Nenhum recibo corresponde aos filtros',
    AppLanguage.arabic => 'لا توجد إيصالات مطابقة للبحث',
    _ => 'No receipts match your filter',
  };

  String get tryAdjustingFilter => switch (effective) {
    AppLanguage.french => 'Essayez de modifier votre recherche ou la catégorie sélectionnée.',
    AppLanguage.spanish => 'Intente cambiar su término de búsqueda o categoría.',
    AppLanguage.german => 'Passen Sie Ihren Suchbegriff oder die Kategorie an.',
    AppLanguage.italian => 'Prova a modificare la ricerca o la categoria selezionata.',
    AppLanguage.portuguese => 'Tente alterar a sua pesquisa ou categoria selecionada.',
    AppLanguage.arabic => 'جرب تعديل كلمة البحث أو الفئة المحددة.',
    _ => 'Try adjusting your search query or selected category.',
  };

  // Privacy Policy Screen
  String get privacyScreenTitle => switch (effective) {
    AppLanguage.french => 'Confidentialité & Sécurité',
    AppLanguage.spanish => 'Privacidad y Seguridad',
    AppLanguage.german => 'Datenschutz & Sicherheit',
    AppLanguage.italian => 'Privacy e Sicurezza',
    AppLanguage.portuguese => 'Privacidade e Segurança',
    AppLanguage.arabic => 'الخصوصية والأمان',
    _ => 'Privacy & Security',
  };

  String get privacySection1Title => switch (effective) {
    AppLanguage.french => '100% sur l\'appareil & Zéro backend',
    AppLanguage.spanish => '100% en el dispositivo y Cero Backend',
    AppLanguage.german => '100% auf dem Gerät & Kein Backend',
    AppLanguage.italian => '100% sul dispositivo & Zero Backend',
    AppLanguage.portuguese => '100% no dispositivo e Zero Backend',
    AppLanguage.arabic => '100% على الجهاز وبدون خوادم خلفية',
    _ => '100% On-Device & Zero Backend',
  };

  String get privacySection1Body => switch (effective) {
    AppLanguage.french =>
      'Scannify ne dispose d\'aucun serveur distant ni base de données cloud. Vos reçus, photos et calculs restent strictement stockés sur votre appareil.',
    AppLanguage.spanish =>
      'Scannify no tiene servidores remotos ni procesamiento en la nube. Sus facturas, fotos y cálculos permanecen exclusivamente en su dispositivo.',
    AppLanguage.german =>
      'Scannify verwendet keine Cloud-Server. Ihre Belege, Fotos und Finanzberechnungen verbleiben vollständig und sicher auf Ihrem lokalen Gerät.',
    AppLanguage.italian =>
      'Scannify non dispone di server remoti o cloud. Tutti gli scontrini, le foto e i calcoli rimangono salvati esclusivamente sul tuo dispositivo.',
    AppLanguage.portuguese =>
      'O Scannify não possui servidores remotos ou na nuvem. Os seus recibos, fotos e cálculos permanecem guardados exclusivamente no seu dispositivo.',
    AppLanguage.arabic =>
      'لا يمتلك سكانيفاي أي خوادم سحابية. تظل جميع إيصالاتك، صورك وحساباتك المالية مخزنة حصرياً على جهازك.',
    _ =>
      'Scannify has no remote database or cloud processing servers. Your receipts, photos, and financial computations remain entirely stored on your device.',
  };

  String get privacySection2Title => switch (effective) {
    AppLanguage.french => 'Reconnaissance OCR locale (Google ML Kit)',
    AppLanguage.spanish => 'Reconocimiento OCR local (Google ML Kit)',
    AppLanguage.german => 'Lokale Texterkennung (Google ML Kit)',
    AppLanguage.italian => 'Riconoscimento OCR locale (Google ML Kit)',
    AppLanguage.portuguese => 'Reconhecimento OCR local (Google ML Kit)',
    AppLanguage.arabic => 'التعرف الضوئي المحلي (Google ML Kit)',
    _ => 'On-Device OCR Recognition (Google ML Kit)',
  };

  String get privacySection2Body => switch (effective) {
    AppLanguage.french =>
      'Le moteur OCR traite vos images directement sur le processeur de votre téléphone. Aucune image de vos justificatifs n\'est jamais téléversée.',
    AppLanguage.spanish =>
      'El motor OCR procesa sus imágenes directamente en el procesador de su teléfono. Ninguna imagen se sube a internet.',
    AppLanguage.german =>
      'Die OCR-Engine verarbeitet Bilder direkt auf Ihrem Smartphone-Prozessor. Kein Belegbild wird jemals ins Internet hochgeladen.',
    AppLanguage.italian =>
      'Il motore OCR elabora le immagini direttamente sul processore del dispositivo. Nessuna immagine viene mai caricata online.',
    AppLanguage.portuguese =>
      'O motor OCR processa as suas imagens diretamente no processador do telemóvel. Nenhuma imagem é carregada para a internet.',
    AppLanguage.arabic =>
      'يعالج محرك التعرف الضوئي الصور مباشرة على معالج هاتفك دون رفع أي صورة إلى الإنترنت على الإطلاق.',
    _ =>
      'The OCR engine processes images directly on your mobile hardware. No receipt photo is ever transmitted across the internet.',
  };

  String get privacySection3Title => switch (effective) {
    AppLanguage.french => 'Stockage chiffré & Contrôle total',
    AppLanguage.spanish => 'Almacenamiento seguro y Control total',
    AppLanguage.german => 'Sichere Speicherung & Volle Kontrolle',
    AppLanguage.italian => 'Archiviazione sicura & Controllo totale',
    AppLanguage.portuguese => 'Armazenamento seguro e Controlo total',
    AppLanguage.arabic => 'تخزين آمن وتحكم كامل',
    _ => 'Secure Local Storage & Total Control',
  };

  String get privacySection3Body => switch (effective) {
    AppLanguage.french =>
      'Vos données sont enregistrées dans le stockage privé de l\'application. Vous pouvez supprimer l\'intégralité de vos justificatifs à tout moment en un clic.',
    AppLanguage.spanish =>
      'Sus datos se guardan en el almacenamiento privado de la app. Puede eliminar la totalidad de sus comprobantes en cualquier momento.',
    AppLanguage.german =>
      'Ihre Daten werden im privaten Speicher der App abgelegt. Sie können alle Belege jederzeit mit einem einzigen Klick vollständig löschen.',
    AppLanguage.italian =>
      'I tuoi dati sono salvati nello spazio privato dell\'applicazione. Puoi cancellare tutti i giustificativi in qualsiasi momento con un clic.',
    AppLanguage.portuguese =>
      'Os seus dados são guardados no armazenamento privado da aplicação. Pode eliminar todos os comprovativos a qualquer momento com um clique.',
    AppLanguage.arabic =>
      'يتم حفظ بياناتك في التخزين الخاص للتطبيق. يمكنك حذف جميع المستندات والإيصالات بضغطة زر واحدة في أي وقت.',
    _ =>
      'Your data is stored in the application\'s private sandbox. You can permanently wipe all receipts and photos at any time in one tap.',
  };

  String get privacySection4Title => switch (effective) {
    AppLanguage.french => '100% Sans Publicité & Respect Total de la Vie Privée',
    AppLanguage.spanish => '100% Sin Publicidad y Máxima Privacidad',
    AppLanguage.german => '100% Werbefrei & Vollständige Privatsphäre',
    AppLanguage.italian => '100% Senza Pubblicità & Massima Privacy',
    AppLanguage.portuguese => '100% Sem Anúncios e Privacidade Absoluta',
    AppLanguage.arabic => 'خالٍ من الإعلانات 100% وخصوصية تامة',
    _ => '100% Ad-Free & Complete Privacy',
  };

  String get privacySection4Body => switch (effective) {
    AppLanguage.french =>
      'Scannify ne contient aucune publicité, aucun traqueur publicitaire et aucun réseau tiers. Toutes les fonctionnalités de numérisation et d\'export sont 100% libres et gratuites.',
    AppLanguage.spanish =>
      'Scannify no contiene publicidad, rastreadores ni SDKs de terceros. Todas las funciones de escaneo y exportación son completamente gratuitas y libres.',
    AppLanguage.german =>
      'Scannify enthält keinerlei Werbung, Werbetracker oder SDKs von Drittanbietern. Sämtliche Scan- und Exportfunktionen sind vollständig kostenlos und unbegrenzt nutzbar.',
    AppLanguage.italian =>
      'Scannify non contiene pubblicità, tracker pubblicitari o SDK di terze parti. Tutte le funzionalità di scansione ed esportazione sono completamente libere e gratuite.',
    AppLanguage.portuguese =>
      'O Scannify não contém anúncios, rastreadores ou SDKs de terceiros. Todas as funcionalidades de digitalização e exportação são totalmente gratuitas e ilimitadas.',
    AppLanguage.arabic =>
      'لا يحتوي Scannify على أي إعلانات أو أدوات تتبع أو مكتبات إعلانية تابعة لجهات خارجية. جميع ميزات المسح الضوئي والتصدير مجانية ومتاحة بالكامل.',
    _ =>
      'Scannify contains zero advertisements, zero ad trackers, and zero third-party ad networks. All scanning and document export capabilities are 100% free and unrestricted.',
  };

  // Localized category names
  String categoryDisplayName(String category) {
    return switch (effective) {
      AppLanguage.french => switch (category) {
        ReceiptCategories.mealsAndDining => 'Repas & Restauration',
        ReceiptCategories.groceries => 'Courses & Alimentation',
        ReceiptCategories.transportAndFuel => 'Transport & Carburant',
        ReceiptCategories.officeSupplies => 'Fournitures de bureau',
        ReceiptCategories.softwareAndTech => 'Logiciels & Tech',
        ReceiptCategories.accommodation => 'Hébergement & Hôtel',
        ReceiptCategories.utilitiesAndTelecom => 'Télécom & Services',
        ReceiptCategories.healthcare => 'Santé & Pharmacie',
        ReceiptCategories.professionalServices => 'Services professionnels',
        _ => 'Autre',
      },
      AppLanguage.spanish => switch (category) {
        ReceiptCategories.mealsAndDining => 'Comidas y Restaurantes',
        ReceiptCategories.groceries => 'Supermercado y Alimentación',
        ReceiptCategories.transportAndFuel => 'Transporte y Combustible',
        ReceiptCategories.officeSupplies => 'Material de oficina',
        ReceiptCategories.softwareAndTech => 'Software y Tecnología',
        ReceiptCategories.accommodation => 'Alojamiento y Hotel',
        ReceiptCategories.utilitiesAndTelecom => 'Telefonía y Suministros',
        ReceiptCategories.healthcare => 'Salud y Farmacia',
        ReceiptCategories.professionalServices => 'Servicios profesionales',
        _ => 'Otros',
      },
      AppLanguage.german => switch (category) {
        ReceiptCategories.mealsAndDining => 'Bewirtung & Verpflegung',
        ReceiptCategories.groceries => 'Lebensmittel & Einkauf',
        ReceiptCategories.transportAndFuel => 'Fahrtkosten & Tanken',
        ReceiptCategories.officeSupplies => 'Bürobedarf',
        ReceiptCategories.softwareAndTech => 'Software & IT',
        ReceiptCategories.accommodation => 'Übernachtung & Hotel',
        ReceiptCategories.utilitiesAndTelecom => 'Telefon & Internet',
        ReceiptCategories.healthcare => 'Gesundheit & Apotheke',
        ReceiptCategories.professionalServices => 'Dienstleistungen & Beratung',
        _ => 'Sonstiges',
      },
      AppLanguage.italian => switch (category) {
        ReceiptCategories.mealsAndDining => 'Ristoranti e Pasti',
        ReceiptCategories.groceries => 'Alimentari e Spesa',
        ReceiptCategories.transportAndFuel => 'Trasporti e Carburante',
        ReceiptCategories.officeSupplies => 'Forniture per ufficio',
        ReceiptCategories.softwareAndTech => 'Software e Tecnologia',
        ReceiptCategories.accommodation => 'Alloggio e Hotel',
        ReceiptCategories.utilitiesAndTelecom => 'Utenze e Telefonia',
        ReceiptCategories.healthcare => 'Salute e Farmacia',
        ReceiptCategories.professionalServices => 'Consulenze e Servizi',
        _ => 'Altro',
      },
      AppLanguage.portuguese => switch (category) {
        ReceiptCategories.mealsAndDining => 'Refeições e Restauração',
        ReceiptCategories.groceries => 'Supermercado e Alimentação',
        ReceiptCategories.transportAndFuel => 'Transporte e Combustível',
        ReceiptCategories.officeSupplies => 'Material de escritório',
        ReceiptCategories.softwareAndTech => 'Software e Tecnologia',
        ReceiptCategories.accommodation => 'Alojamento e Hotel',
        ReceiptCategories.utilitiesAndTelecom => 'Telecomunicações e Serviços',
        ReceiptCategories.healthcare => 'Saúde e Farmácia',
        ReceiptCategories.professionalServices => 'Serviços profissionais',
        _ => 'Outros',
      },
      AppLanguage.arabic => switch (category) {
        ReceiptCategories.mealsAndDining => 'وجبات ومطاعم',
        ReceiptCategories.groceries => 'بقالة وأغذية',
        ReceiptCategories.transportAndFuel => 'مواصلات ووقود',
        ReceiptCategories.officeSupplies => 'أدوات ومستلزمات مكتبية',
        ReceiptCategories.softwareAndTech => 'برمجيات وتكنولوجيا',
        ReceiptCategories.accommodation => 'إقامة وفنادق',
        ReceiptCategories.utilitiesAndTelecom => 'فواتير واتصالات',
        ReceiptCategories.healthcare => 'صحة وصيدلية',
        ReceiptCategories.professionalServices => 'خدمات واستشارات',
        _ => 'أخرى',
      },
      _ => category,
    };
  }

  String verifiedCountBadge(int count) => switch (effective) {
    AppLanguage.french => '$count certifié(s)',
    AppLanguage.spanish => '$count verificado(s)',
    AppLanguage.german => '$count geprüft',
    AppLanguage.italian => '$count verificati',
    AppLanguage.portuguese => '$count verificado(s)',
    AppLanguage.arabic => '$count موثق',
    _ => '$count verified',
  };

  String get errorLoadingData => switch (effective) {
    AppLanguage.french => 'Erreur de chargement',
    AppLanguage.spanish => 'Error al cargar datos',
    AppLanguage.german => 'Fehler beim Laden',
    AppLanguage.italian => 'Errore di caricamento',
    AppLanguage.portuguese => 'Erro ao carregar dados',
    AppLanguage.arabic => 'خطأ في تحميل البيانات',
    _ => 'Failed to load',
  };

  String noReceiptsInMonthToExport(String month) => switch (effective) {
    AppLanguage.french => 'Aucun reçu pour $month. Scannez un premier reçu !',
    AppLanguage.spanish => 'Sin recibos en $month. ¡Escanee su primer recibo!',
    AppLanguage.german => 'Keine Belege für $month. Scannen Sie einen ersten Beleg!',
    AppLanguage.italian => 'Nessuno scontrino per $month. Scansiona il primo!',
    AppLanguage.portuguese => 'Nenhum recibo em $month. Digitalize o seu primeiro recibo!',
    AppLanguage.arabic => 'لا توجد إيصالات لشهر $month. امسح إيصالك الأول!',
    _ => 'No receipts in $month to export.',
  };

  String quotaScansBadge(String text) => switch (effective) {
    AppLanguage.french => '$text scans',
    AppLanguage.spanish => '$text escaneos',
    AppLanguage.german => '$text Scans',
    AppLanguage.italian => '$text scansioni',
    AppLanguage.portuguese => '$text digitalizações',
    AppLanguage.arabic => '$text مسح',
    _ => '$text scans',
  };

  String get categoryBreakdown => switch (effective) {
    AppLanguage.french => 'Répartition par catégorie',
    AppLanguage.spanish => 'Desglose por categoría',
    AppLanguage.german => 'Aufschlüsselung nach Kategorie',
    AppLanguage.italian => 'Ripartizione per categoria',
    AppLanguage.portuguese => 'Divisão por categoria',
    AppLanguage.arabic => 'توزيع النفقات حسب الفئة',
    _ => 'Category Breakdown',
  };

  String exportFormatCta(String ext) => switch (effective) {
    AppLanguage.french => 'Exporter en $ext',
    AppLanguage.spanish => 'Exportar en $ext',
    AppLanguage.german => 'Als $ext exportieren',
    AppLanguage.italian => 'Esporta in $ext',
    AppLanguage.portuguese => 'Exportar em $ext',
    AppLanguage.arabic => 'تصدير بصيغة $ext',
    _ => 'Export $ext Report',
  };

  String exportReadySuccess(String filename) => switch (effective) {
    AppLanguage.french => 'Export $filename prêt.',
    AppLanguage.spanish => 'Exportación $filename lista.',
    AppLanguage.german => 'Export $filename ist fertig.',
    AppLanguage.italian => 'Esportazione $filename pronta.',
    AppLanguage.portuguese => 'Exportação $filename pronta.',
    AppLanguage.arabic => 'تم تجهيز تصدير $filename.',
    _ => 'Export $filename ready.',
  };

  String get exportNoReceiptsError => switch (effective) {
    AppLanguage.french => 'Aucun reçu à exporter pour la période sélectionnée.',
    AppLanguage.spanish => 'No hay recibos para exportar en este período.',
    AppLanguage.german => 'Keine Belege für den gewählten Zeitraum zum Exportieren.',
    AppLanguage.italian => 'Nessuno scontrino da esportare per il periodo selezionato.',
    AppLanguage.portuguese => 'Nenhum recibo para exportar no período selecionado.',
    AppLanguage.arabic => 'لا توجد إيصالات للتصدير في الفترة المحددة.',
    _ => 'No receipts to export for the selected period.',
  };

  String get attachReceiptPhotosTitle => switch (effective) {
    AppLanguage.french => 'Annexer les photos de reçus',
    AppLanguage.spanish => 'Adjuntar fotos de recibos',
    AppLanguage.german => 'Belegfotos anfügen',
    AppLanguage.italian => 'Allega foto degli scontrini',
    AppLanguage.portuguese => 'Anexar fotos dos recibos',
    AppLanguage.arabic => 'إرفاق صور الإيصالات',
    _ => 'Attach Receipt Photos',
  };

  String sortOrderLabel(ReceiptSortOrder order) => switch (effective) {
    AppLanguage.french => switch (order) {
      ReceiptSortOrder.dateDesc => 'Plus récents',
      ReceiptSortOrder.dateAsc => 'Plus anciens',
      ReceiptSortOrder.amountDesc => 'Montant décroissant',
      ReceiptSortOrder.amountAsc => 'Montant croissant',
      ReceiptSortOrder.merchantAsc => 'Commerçant (A–Z)',
    },
    AppLanguage.spanish => switch (order) {
      ReceiptSortOrder.dateDesc => 'Más recientes',
      ReceiptSortOrder.dateAsc => 'Más antiguos',
      ReceiptSortOrder.amountDesc => 'Mayor importe',
      ReceiptSortOrder.amountAsc => 'Menor importe',
      ReceiptSortOrder.merchantAsc => 'Comercio (A–Z)',
    },
    AppLanguage.german => switch (order) {
      ReceiptSortOrder.dateDesc => 'Neueste zuerst',
      ReceiptSortOrder.dateAsc => 'Älteste zuerst',
      ReceiptSortOrder.amountDesc => 'Höchster Betrag',
      ReceiptSortOrder.amountAsc => 'Niedrigster Betrag',
      ReceiptSortOrder.merchantAsc => 'Händler (A–Z)',
    },
    AppLanguage.italian => switch (order) {
      ReceiptSortOrder.dateDesc => 'Più recenti',
      ReceiptSortOrder.dateAsc => 'Più vecchi',
      ReceiptSortOrder.amountDesc => 'Importo decrescente',
      ReceiptSortOrder.amountAsc => 'Importo crescente',
      ReceiptSortOrder.merchantAsc => 'Fornitore (A–Z)',
    },
    AppLanguage.portuguese => switch (order) {
      ReceiptSortOrder.dateDesc => 'Mais recentes',
      ReceiptSortOrder.dateAsc => 'Mais antigos',
      ReceiptSortOrder.amountDesc => 'Maior valor',
      ReceiptSortOrder.amountAsc => 'Menor valor',
      ReceiptSortOrder.merchantAsc => 'Comerciante (A–Z)',
    },
    AppLanguage.arabic => switch (order) {
      ReceiptSortOrder.dateDesc => 'الأحدث أولاً',
      ReceiptSortOrder.dateAsc => 'الأقدم أولاً',
      ReceiptSortOrder.amountDesc => 'المبلغ: من الأعلى للأقل',
      ReceiptSortOrder.amountAsc => 'المبلغ: من الأقل للأعلى',
      ReceiptSortOrder.merchantAsc => 'التاجر (أ–ي)',
    },
    _ => switch (order) {
      ReceiptSortOrder.dateDesc => 'Newest First',
      ReceiptSortOrder.dateAsc => 'Oldest First',
      ReceiptSortOrder.amountDesc => 'Highest Amount',
      ReceiptSortOrder.amountAsc => 'Lowest Amount',
      ReceiptSortOrder.merchantAsc => 'Merchant (A–Z)',
    },
  };

  String get sortBy => switch (effective) {
    AppLanguage.french => 'Trier par',
    AppLanguage.spanish => 'Ordenar por',
    AppLanguage.german => 'Sortieren nach',
    AppLanguage.italian => 'Ordina per',
    AppLanguage.portuguese => 'Ordenar por',
    AppLanguage.arabic => 'ترتيب حسب',
    _ => 'Sort by',
  };

  String get searchHistoryHint => switch (effective) {
    AppLanguage.french => 'Rechercher un commerçant ou une catégorie...',
    AppLanguage.spanish => 'Buscar un comercio o categoría...',
    AppLanguage.german => 'Nach Händler oder Kategorie suchen...',
    AppLanguage.italian => 'Cerca fornitore o categoria...',
    AppLanguage.portuguese => 'Pesquisar comerciante ou categoria...',
    AppLanguage.arabic => 'بحث عن تاجر أو فئة...',
    _ => 'Search by merchant or category...',
  };

  String get allDates => switch (effective) {
    AppLanguage.french => 'Toutes les dates',
    AppLanguage.spanish => 'Todas las fechas',
    AppLanguage.german => 'Alle Daten',
    AppLanguage.italian => 'Tutte le date',
    AppLanguage.portuguese => 'Todas as datas',
    AppLanguage.arabic => 'جميع التواريخ',
    _ => 'All Dates',
  };

  String get filterByMonth => switch (effective) {
    AppLanguage.french => 'Filtrer par mois',
    AppLanguage.spanish => 'Filtrar por mes',
    AppLanguage.german => 'Nach Monat filtern',
    AppLanguage.italian => 'Filtra per mese',
    AppLanguage.portuguese => 'Filtrar por mês',
    AppLanguage.arabic => 'تصفية حسب الشهر',
    _ => 'Filter by month',
  };

  String get noReceiptsFound => switch (effective) {
    AppLanguage.french => 'Aucun reçu trouvé',
    AppLanguage.spanish => 'No se encontraron recibos',
    AppLanguage.german => 'Keine Belege gefunden',
    AppLanguage.italian => 'Nessuno scontrino trovato',
    AppLanguage.portuguese => 'Nenhum recibo encontrado',
    AppLanguage.arabic => 'لم يتم العثور على إيصالات',
    _ => 'No matching receipts',
  };

  String get noReceiptsFoundSubtitle => switch (effective) {
    AppLanguage.french => 'Modifiez vos filtres ou scannez un nouveau reçu.',
    AppLanguage.spanish => 'Cambie los filtros o escanee un nuevo recibo.',
    AppLanguage.german => 'Passen Sie Ihre Filter an oder scannen Sie einen neuen Beleg.',
    AppLanguage.italian => 'Modifica i filtri o scansiona un nuovo scontrino.',
    AppLanguage.portuguese => 'Altere os filtros ou digitalize um novo recibo.',
    AppLanguage.arabic => 'عدل عوامل التصفية أو امسح إيصالاً جديداً.',
    _ => 'Adjust your filters or scan a new receipt.',
  };

  String documentTypeName(FinancialDocumentType type) => switch (effective) {
    AppLanguage.french => switch (type) {
      FinancialDocumentType.invoice => 'Facture',
      FinancialDocumentType.receipt => 'Ticket',
      FinancialDocumentType.quote => 'Devis',
      FinancialDocumentType.creditNote => 'Avoir',
      FinancialDocumentType.unknown => 'Document',
    },
    AppLanguage.spanish => switch (type) {
      FinancialDocumentType.invoice => 'Factura',
      FinancialDocumentType.receipt => 'Recibo',
      FinancialDocumentType.quote => 'Presupuesto',
      FinancialDocumentType.creditNote => 'Factura rectificativa',
      FinancialDocumentType.unknown => 'Documento',
    },
    AppLanguage.german => switch (type) {
      FinancialDocumentType.invoice => 'Rechnung',
      FinancialDocumentType.receipt => 'Beleg',
      FinancialDocumentType.quote => 'Angebot',
      FinancialDocumentType.creditNote => 'Gutschrift',
      FinancialDocumentType.unknown => 'Dokument',
    },
    AppLanguage.italian => switch (type) {
      FinancialDocumentType.invoice => 'Fattura',
      FinancialDocumentType.receipt => 'Scontrino',
      FinancialDocumentType.quote => 'Preventivo',
      FinancialDocumentType.creditNote => 'Nota di credito',
      FinancialDocumentType.unknown => 'Documento',
    },
    AppLanguage.portuguese => switch (type) {
      FinancialDocumentType.invoice => 'Fatura',
      FinancialDocumentType.receipt => 'Recibo',
      FinancialDocumentType.quote => 'Orçamento',
      FinancialDocumentType.creditNote => 'Nota de crédito',
      FinancialDocumentType.unknown => 'Documento',
    },
    AppLanguage.arabic => switch (type) {
      FinancialDocumentType.invoice => 'فاتورة',
      FinancialDocumentType.receipt => 'إيصال',
      FinancialDocumentType.quote => 'عرض أسعار',
      FinancialDocumentType.creditNote => 'إشعار دائن',
      FinancialDocumentType.unknown => 'مستند',
    },
    _ => switch (type) {
      FinancialDocumentType.invoice => 'Invoice',
      FinancialDocumentType.receipt => 'Receipt',
      FinancialDocumentType.quote => 'Quote',
      FinancialDocumentType.creditNote => 'Credit Note',
      FinancialDocumentType.unknown => 'Document',
    },
  };

  String get manualEntryActive => switch (effective) {
    AppLanguage.french =>
      'Saisie manuelle active : complétez et vérifiez les informations du reçu.',
    AppLanguage.spanish =>
      'Entrada manual activa: complete y verifique los datos del recibo.',
    AppLanguage.german =>
      'Manuelle Eingabe aktiv: Belegdaten eingeben und prüfen.',
    AppLanguage.italian =>
      'Inserimento manuale attivo: compila e verifica i dati dello scontrino.',
    AppLanguage.portuguese =>
      'Inserção manual ativa: preencha e confirme os dados do recibo.',
    AppLanguage.arabic =>
      'الإدخال اليدوي نشط: يرجى إدخال وتدقيق معلومات الإيصال.',
    _ => 'Manual entry active: complete and verify receipt information.',
  };

  String verifyExtractedFields(int pct) => switch (effective) {
    AppLanguage.french => 'Veuillez vérifier les champs extraits ($pct% confiance)',
    AppLanguage.spanish => 'Por favor verifique los campos extraídos ($pct% confianza)',
    AppLanguage.german => 'Bitte extrahierte Felder prüfen ($pct% Zuverlässigkeit)',
    AppLanguage.italian => 'Verifica i campi estratti ($pct% affidabilità)',
    AppLanguage.portuguese => 'Valide os campos extraídos ($pct% confiança)',
    AppLanguage.arabic => 'يرجى تدقيق الحقول المستخرجة ($pct% دقة)',
    _ => 'Please verify extracted fields ($pct% confidence)',
  };

  String ocrExtractionSuccess(int pct) => switch (effective) {
    AppLanguage.french => 'Extraction OCR réussie ($pct% confiance)',
    AppLanguage.spanish => 'Extracción OCR correcta ($pct% confianza)',
    AppLanguage.german => 'OCR-Erkennung erfolgreich ($pct% Zuverlässigkeit)',
    AppLanguage.italian => 'Estrazione OCR completata ($pct% affidabilità)',
    AppLanguage.portuguese => 'Extração OCR bem-sucedida ($pct% confiança)',
    AppLanguage.arabic => 'تم استخراج البيانات بنجاح ($pct% دقة)',
    _ => 'OCR extraction successful ($pct% confidence)',
  };

  String dateAmbiguousWarning(String raw) => switch (effective) {
    AppLanguage.french =>
      'Note : Le format de la date ($raw) est ambigu (JJ/MM vs MM/JJ). Veuillez confirmer.',
    AppLanguage.spanish =>
      'Nota: El formato de fecha ($raw) es ambiguo (DD/MM vs MM/DD). Confirme por favor.',
    AppLanguage.german =>
      'Hinweis: Datumsformat ($raw) ist mehrdeutig (TT/MM vs. MM/TT). Bitte bestätigen.',
    AppLanguage.italian =>
      'Nota: Il formato data ($raw) è ambiguo (GG/MM vs MM/GG). Conferma per favore.',
    AppLanguage.portuguese =>
      'Nota: O formato da data ($raw) é ambíguo (DD/MM vs MM/DD). Confirme por favor.',
    AppLanguage.arabic =>
      'ملاحظة: صيغة التاريخ ($raw) غير محددة (يوم/شهر أم شهر/يوم). يرجى التأكيد.',
    _ =>
      'Note: Date format ($raw) is ambiguous (DD/MM vs MM/DD). Please confirm.',
  };

  String get financialDetailsAndVat => switch (effective) {
    AppLanguage.french => 'Détails financiers & TVA',
    AppLanguage.spanish => 'Detalles financieros e IVA',
    AppLanguage.german => 'Finanzdaten & MwSt',
    AppLanguage.italian => 'Dettagli finanziari e IVA',
    AppLanguage.portuguese => 'Detalhes financeiros e IVA',
    AppLanguage.arabic => 'التفاصيل المالية والضريبة',
    _ => 'Financial Details & VAT',
  };

  String get taxAndInvoiceDetails => switch (effective) {
    AppLanguage.french => 'Détails Fiscaux & Facture',
    AppLanguage.spanish => 'Detalles Fiscales y Factura',
    AppLanguage.german => 'Steuer- & Rechnungsdetails',
    AppLanguage.italian => 'Dettagli Fiscali e Fattura',
    AppLanguage.portuguese => 'Detalhes Fiscais e Fatura',
    AppLanguage.arabic => 'تفاصيل الضريبة والفاتورة',
    _ => 'Tax & Invoice Details',
  };

  String itemsCountLabel(int count) => switch (effective) {
    AppLanguage.french => '$count ${count <= 1 ? "article" : "articles"}',
    AppLanguage.spanish => '$count ${count <= 1 ? "artículo" : "artículos"}',
    AppLanguage.german => '$count ${count <= 1 ? "Posten" : "Posten"}',
    AppLanguage.italian => '$count ${count <= 1 ? "voce" : "voci"}',
    AppLanguage.portuguese => '$count ${count <= 1 ? "item" : "itens"}',
    AppLanguage.arabic => '$count ${count <= 1 ? "بند" : "بنود"}',
    _ => '$count ${count <= 1 ? "item" : "items"}',
  };

  String get lineItemsTitle => switch (effective) {
    AppLanguage.french => 'Articles & prestations',
    AppLanguage.spanish => 'Artículos y servicios',
    AppLanguage.german => 'Einzelposten',
    AppLanguage.italian => 'Voci e prestazioni',
    AppLanguage.portuguese => 'Itens e serviços',
    AppLanguage.arabic => 'البنود والخدمات',
    _ => 'Line items',
  };

  String get discountLabel => switch (effective) {
    AppLanguage.french => 'Remise',
    AppLanguage.spanish => 'Descuento',
    AppLanguage.german => 'Rabatt',
    AppLanguage.italian => 'Sconto',
    AppLanguage.portuguese => 'Desconto',
    AppLanguage.arabic => 'خصم',
    _ => 'Discount',
  };

  String get vatLabel => switch (effective) {
    AppLanguage.french => 'TVA',
    AppLanguage.spanish => 'IVA',
    AppLanguage.german => 'MwSt',
    AppLanguage.italian => 'IVA',
    AppLanguage.portuguese => 'IVA',
    AppLanguage.arabic => 'الضريبة',
    _ => 'VAT',
  };
}
