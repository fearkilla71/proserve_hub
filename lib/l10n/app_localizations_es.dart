// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'ProServe Hub';

  @override
  String get selectService => 'Seleccionar un Servicio';

  @override
  String get browseContractors => 'Buscar Contratistas';

  @override
  String get savedContractors => 'Contratistas Guardados';

  @override
  String get instantBook => 'Reserva Instantánea';

  @override
  String get viewAvailability => 'Ver Disponibilidad';

  @override
  String get requestJob => 'Solicitar Trabajo';

  @override
  String get cancelJob => 'Cancelar Trabajo';

  @override
  String get referralPromo => 'Referidos y Promos';

  @override
  String get bookingConfirmed => 'Reserva Confirmada';

  @override
  String get noErrors => 'No hay errores registrados aún.';

  @override
  String get quickActions => 'Acciones rápidas';

  @override
  String get startRequest => 'Iniciar solicitud';

  @override
  String get browsePros => 'Buscar profesionales';

  @override
  String get messages => 'Mensajes';

  @override
  String get projectTracker => 'Seguimiento de proyecto';

  @override
  String get savedPros => 'Profesionales guardados';

  @override
  String get referral => 'Referidos';

  @override
  String welcome(String name) {
    return 'Bienvenido, $name';
  }

  @override
  String get notifications => 'Notificaciones';

  @override
  String get settings => 'Configuración';

  @override
  String get language => 'Idioma';

  @override
  String get signOut => 'Cerrar Sesión';

  @override
  String get signIn => 'Iniciar Sesión';

  @override
  String get profile => 'Perfil';

  @override
  String get home => 'Inicio';

  @override
  String get search => 'Buscar';

  @override
  String get project => 'Proyecto';

  @override
  String get community => 'Comunidad';

  @override
  String get tools => 'Herramientas';

  @override
  String get jobs => 'Trabajos';

  @override
  String get plan => 'Plan';

  @override
  String get renderTool => 'Herramienta de Renderizado';

  @override
  String get compare => 'Comparar';

  @override
  String get exitCompare => 'Salir de comparar';

  @override
  String get before => 'ANTES';

  @override
  String get after => 'DESPUÉS';

  @override
  String get myEstimates => 'Mis Estimaciones';

  @override
  String get noEstimatesYet => 'Sin estimaciones aún';

  @override
  String get getAiEstimate => 'Obtener Estimación IA';

  @override
  String get postAsJobRequest => 'Publicar como Solicitud';

  @override
  String get deleteEstimate => 'Eliminar Estimación';

  @override
  String get receiptsExpenses => 'Recibos y Gastos';

  @override
  String get exportCsv => 'Exportar CSV';

  @override
  String get exportPdf => 'Exportar PDF';

  @override
  String get noReceiptsYet => 'Sin recibos aún.';

  @override
  String get availabilityCalendar => 'Calendario de Disponibilidad';

  @override
  String get allDayAvailable => 'Todo el Día Disponible';

  @override
  String get allDayUnavailable => 'Todo el Día No Disponible';

  @override
  String get aiEstimator => 'Estimador IA';

  @override
  String get startNewRequest => 'Comenzar Nueva Solicitud';

  @override
  String get activity => 'Actividad';

  @override
  String get noNotificationsYet => 'Sin notificaciones aún';

  @override
  String get chooseNotifications => 'Elige qué notificaciones quieres recibir.';

  @override
  String get referralDashboard => 'Panel de Referidos';

  @override
  String get totalReferrals => 'Total de Referidos';

  @override
  String get creditsEarned => 'Créditos Ganados';

  @override
  String get yourReferralCode => 'Tu Código de Referido';

  @override
  String get interiorPainting => 'Pintura Interior';

  @override
  String get cabinetPainting => 'Pintura de Gabinetes';

  @override
  String get drywallRepair => 'Reparación de Drywall';

  @override
  String get pressureWashing => 'Lavado a Presión';

  @override
  String get exteriorPainting => 'Pintura Exterior';

  @override
  String get aiPriceMatchGuarantee => 'Garantía de Igualación de Precio con IA';

  @override
  String get aiPriceMatch => 'Igualación de Precio con IA';

  @override
  String priceGuaranteeThreshold(String threshold) {
    return 'Si tu costo final supera nuestra estimación de IA por más de $threshold, te acreditaremos la diferencia.';
  }

  @override
  String get costBreakdown => 'Desglose de Costos';

  @override
  String get labor => 'Mano de obra';

  @override
  String get materials => 'Materiales';

  @override
  String get platformFee => 'Tarifa de la plataforma';

  @override
  String get escrowProtection => 'Protección de depósito';

  @override
  String get maintenanceReminders => 'Recordatorios de mantenimiento';

  @override
  String get maintenanceDue => 'Mantenimiento pendiente';

  @override
  String get book => 'Reservar';

  @override
  String get seasonalDeals => 'Ofertas y promociones';

  @override
  String hoursLeft(int hours) {
    return 'Quedan $hours h';
  }

  @override
  String off(int percent) {
    return '$percent% DE DESCUENTO';
  }

  @override
  String get neighborhoodActivity => 'En tu vecindario';

  @override
  String homesNearYou(int count) {
    return '$count hogares cerca de ti este mes';
  }

  @override
  String get savedProjects => 'Proyectos guardados';

  @override
  String get noProjectsYet => 'Aún no hay proyectos';

  @override
  String get createBoard => 'Crear tablero';

  @override
  String get boardName => 'Nombre del tablero';

  @override
  String get notes => 'Notas';

  @override
  String get zeroInterest => '0% DE INTERÉS';

  @override
  String get payInThree => 'Paga en 3';

  @override
  String get payInSix => 'Paga en 6';

  @override
  String perMonth(String amount) {
    return '$amount/mes';
  }

  @override
  String get choosePaymentPlan => 'Elige un plan de pago';

  @override
  String get financingAvailable => 'Financiamiento disponible';

  @override
  String get topMatchedPros => 'Profesionales más compatibles';

  @override
  String prosInvited(int count) {
    return '$count profesionales invitados; las cotizaciones llegarán pronto';
  }

  @override
  String get timeRemaining => 'Tiempo restante';

  @override
  String get verifiedPro => 'Verificado';

  @override
  String get trustedPro => 'Profesional de confianza';

  @override
  String get elitePro => 'Profesional élite';

  @override
  String get addPhoto => 'Agregar foto';

  @override
  String get requestPhoto => 'Solicitar foto';

  @override
  String get photoRequested => '¡Foto solicitada!';

  @override
  String get languageSystemDefault => 'Predeterminado del sistema';

  @override
  String get selectLanguage => 'Seleccionar idioma';

  @override
  String get you => 'Tú';

  @override
  String get customer => 'Cliente';

  @override
  String get setPassword => 'Configurar contraseña';

  @override
  String get notificationSettings => 'Configuración de notificaciones';

  @override
  String get notificationSettingsDescription =>
      'Recibe alertas cuando los profesionales te envíen estimaciones de costo o mensajes.';

  @override
  String get allowPushNotifications => 'Permitir notificaciones push';

  @override
  String get working => 'Trabajando…';

  @override
  String get contactSupport => 'Contactar soporte';

  @override
  String get help => 'Ayuda';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get caNoticeAtCollection => 'Aviso de California al recopilar datos';

  @override
  String get termsOfUse => 'Términos de uso';

  @override
  String get reportTechnicalProblem => 'Reportar un problema técnico';

  @override
  String get doNotSellOrShareMyInfo => 'No vender ni compartir mi información';

  @override
  String get deactivateAccount => 'Desactivar cuenta';

  @override
  String get deleteAccountData => 'Eliminar los datos de mi cuenta';

  @override
  String get noEmailFound =>
      'No se encontró un correo electrónico para esta cuenta.';

  @override
  String passwordResetEmailSent(String email) {
    return 'Correo para restablecer la contraseña enviado a $email';
  }

  @override
  String failedToSendEmail(String error) {
    return 'No se pudo enviar el correo: $error';
  }

  @override
  String get notificationsEnabled => 'Notificaciones activadas.';

  @override
  String get notificationsPermissionNotGranted =>
      'No se concedió el permiso de notificaciones.';

  @override
  String failedToEnableNotifications(String error) {
    return 'No se pudieron activar las notificaciones: $error';
  }

  @override
  String get signedOut => 'Sesión cerrada.';

  @override
  String signOutFailed(String error) {
    return 'No se pudo cerrar sesión: $error';
  }

  @override
  String get versionLoading => 'Versión …';

  @override
  String get subscriptionPlansTitle => 'Planes de suscripción';

  @override
  String get subscriptionCurrentPlan => 'Plan actual';

  @override
  String get subscriptionUpdatingStatus => 'Actualizando estado…';

  @override
  String get subscriptionTierBasic => 'Básico';

  @override
  String get subscriptionTierPro => 'Pro';

  @override
  String get subscriptionTierEnterprise => 'Enterprise';

  @override
  String get subscriptionPriceFree => 'Gratis';

  @override
  String get subscriptionPopular => 'POPULAR';

  @override
  String get subscriptionCurrent => 'ACTUAL';

  @override
  String get subscriptionFeatureJobFeedAccess =>
      'Acceso al listado de trabajos';

  @override
  String get subscriptionFeatureAcceptCustomerBids =>
      'Aceptar ofertas de clientes';

  @override
  String get subscriptionFeatureCommunityFeed => 'Feed de la comunidad';

  @override
  String get subscriptionFeatureEverythingBasic => 'Todo lo de Básico';

  @override
  String get subscriptionFeaturePricingCalculator => 'Calculadora de precios';

  @override
  String get subscriptionFeatureCostEstimator => 'Estimador de costos';

  @override
  String get subscriptionFeatureAiInvoiceMaker => 'Creador de facturas con IA';

  @override
  String get subscriptionFeatureRenderTool => 'Herramienta de renders';

  @override
  String get subscriptionFeatureEverythingPro => 'Todo lo de Pro';

  @override
  String get subscriptionFeatureProfitLossDashboard =>
      'Panel de pérdidas y ganancias';

  @override
  String get subscriptionFeaturePriorityJobFeed =>
      'Trabajos prioritarios (30 min antes)';

  @override
  String get subscriptionFeatureUnlimitedAi =>
      'Estimaciones y renders de IA ilimitados';

  @override
  String get subscriptionFeatureInvoicePaymentCollection =>
      'Cobro de pagos de facturas';

  @override
  String get subscriptionFeatureSubcontractorBoard =>
      'Tablero de subcontratistas';

  @override
  String get subscriptionFeatureCrewRoster => 'Equipo y programación';

  @override
  String subscriptionManagedSettings(String settingsName) {
    return 'Suscripción mensual con renovación automática. Puedes cancelar cuando quieras en la configuración de $settingsName.';
  }

  @override
  String get subscriptionOpeningCheckout => 'Abriendo pago...';

  @override
  String get subscriptionUpgradeWithCard => 'Mejorar con tarjeta';

  @override
  String get subscriptionOpeningStore => 'Abriendo tienda...';

  @override
  String subscriptionSubscribeWithStorePrice(String storeName, String price) {
    return 'Suscribirse con $storeName ($price)';
  }

  @override
  String subscriptionSubscribeWithStore(String storeName) {
    return 'Suscribirse con $storeName';
  }

  @override
  String subscriptionStoreUnavailableShort(String storeName) {
    return 'Suscripción de $storeName no disponible';
  }

  @override
  String get subscriptionIosManagementCopy =>
      'Las suscripciones se compran con compras dentro de la app de Apple y se administran en la configuración de Apple ID.';

  @override
  String get subscriptionAndroidManagementCopy =>
      'Consejo: Google Play es la mejor opción para suscripciones móviles. Stripe es una alternativa flexible y funciona fuera del flujo de la tienda.';

  @override
  String get subscriptionInformation => 'Información de la suscripción';

  @override
  String subscriptionAutoRenewInfo(String accountName) {
    return 'Los planes Pro y Enterprise son suscripciones mensuales con renovación automática. El pago se carga a tu cuenta de $accountName al confirmar la compra y se renueva automáticamente a menos que canceles al menos 24 horas antes de que termine el período actual.';
  }

  @override
  String get subscriptionRestorePurchases => 'Restaurar compras';

  @override
  String get subscriptionRestoreComplete =>
      'Restauración completa. Revisando el estado de la suscripción.';

  @override
  String subscriptionRestoreFailed(String error) {
    return 'No se pudo restaurar: $error';
  }

  @override
  String get subscriptionPurchasePending =>
      'La compra está pendiente de confirmación.';

  @override
  String get subscriptionPurchaseFailed => 'La compra falló.';

  @override
  String get subscriptionPurchaseCanceled => 'Compra cancelada.';

  @override
  String get subscriptionEnterpriseActivated =>
      'Suscripción Enterprise activada.';

  @override
  String get subscriptionProActivated => 'Suscripción Pro activada.';

  @override
  String subscriptionVerificationFailed(String error) {
    return 'Falló la verificación de la suscripción: $error';
  }

  @override
  String get subscriptionCheckoutBrowserReturn =>
      'Completa el pago en el navegador y vuelve a la app. Actualizaremos tu estado automáticamente.';

  @override
  String subscriptionStoreTierUnavailable(String tierName) {
    return 'La suscripción de tienda para $tierName aún no está disponible.';
  }

  @override
  String subscriptionStoreUnavailable(String storeName) {
    return 'Las suscripciones de $storeName no están disponibles ahora. Inténtalo otra vez con una cuenta de tienda conectada.';
  }

  @override
  String subscriptionProductLoadFailed(String error) {
    return 'No se pudieron cargar los productos de suscripción: $error';
  }

  @override
  String subscriptionMissingProducts(String productIds) {
    return 'Faltan productos de suscripción en App Store Connect: $productIds.';
  }

  @override
  String get subscriptionNoProductsAvailable =>
      'Aún no hay productos de suscripción disponibles para esta cuenta sandbox de Apple.';

  @override
  String get active => 'Activo';

  @override
  String get subscribe => 'Suscribirse';

  @override
  String get manageSubscription => 'Administrar suscripción';

  @override
  String get toolsTitle => 'Herramientas';

  @override
  String get toolsSubtitle =>
      'Gana trabajos, cotiza más rápido, administra proyectos y cobra pagos';

  @override
  String get toolsTodayTitle => 'Hoy';

  @override
  String get toolsTodaySubtitle =>
      'Tu sistema operativo de contratista de un vistazo.';

  @override
  String get toolsPayoutsReady => 'Pagos listos';

  @override
  String get toolsPayoutsNotConnected => 'Conectar pagos';

  @override
  String toolsLeadCredits(int count) {
    return '$count créditos de leads';
  }

  @override
  String get toolsProActive => 'Pro activo';

  @override
  String get toolsProLocked => 'Pro bloqueado';

  @override
  String get toolsEnterpriseActive => 'Enterprise activo';

  @override
  String get toolsEnterpriseLocked => 'Enterprise bloqueado';

  @override
  String get toolsReviewSetup => 'Revisar configuración';

  @override
  String get contractorProTitle => 'Contractor Pro';

  @override
  String get contractorProPrice => '\$11.99 / mes';

  @override
  String get contractorProUnlocks =>
      'Desbloquea facturas, precios, presupuestos, renders y mejores herramientas diarias.';

  @override
  String get accessPro => 'Pro';

  @override
  String get accessEnterprise => 'Enterprise';

  @override
  String get lockedPro => 'Pro bloqueado';

  @override
  String get lockedEnterprise => 'Enterprise bloqueado';

  @override
  String get toolsSectionWinWork => 'Ganar trabajos';

  @override
  String get toolsSectionEstimateQuote => 'Presupuestar y cotizar';

  @override
  String get toolsSectionGetPaid => 'Cobrar pagos';

  @override
  String get toolsSectionManageJobs => 'Administrar trabajos';

  @override
  String get toolsSectionGrowOperations => 'Crecer operaciones';

  @override
  String get toolAiInvoiceMakerTitle => 'Creador de facturas con IA';

  @override
  String get toolAiInvoiceMakerSubtitle =>
      'Elige un cliente o trabajo, crea partidas, términos, depósitos y enlaces de pago.';

  @override
  String get toolInvoicesTitle => 'Facturas';

  @override
  String get toolInvoicesSubtitle =>
      'Filtra borradores, enviadas, pagadas y vencidas; envía recordatorios.';

  @override
  String get toolPricingCalculatorTitle => 'Calculadora de precios';

  @override
  String get toolPricingCalculatorSubtitle =>
      'Usa mano de obra, materiales, margen y mercado para poner precio al trabajo.';

  @override
  String get toolCostEstimatorTitle => 'Estimador de costos';

  @override
  String get toolCostEstimatorSubtitle =>
      'Crea presupuestos detallados con supuestos editables y revisiones.';

  @override
  String get toolRenderToolTitle => 'Herramienta de renders';

  @override
  String get toolRenderToolSubtitle =>
      'Previsualiza colores, habitaciones y superficies antes de enviar una propuesta.';

  @override
  String get toolRenderGalleryTitle => 'Galería de renders';

  @override
  String get toolRenderGallerySubtitle =>
      'Organiza renders por cliente, trabajo, habitación y paquetes para compartir.';

  @override
  String get toolSavedEstimatesTitle => 'Presupuestos guardados';

  @override
  String get toolSavedEstimatesSubtitle =>
      'Duplica, revisa, compara, comparte y convierte presupuestos.';

  @override
  String get toolSmartSchedulingTitle => 'Programación inteligente con IA';

  @override
  String get toolSmartSchedulingSubtitle =>
      'Equilibra equipos, prioridades, traslados y riesgo climático en la semana.';

  @override
  String get toolQualityInspectorTitle => 'Inspector de calidad con IA';

  @override
  String get toolQualityInspectorSubtitle =>
      'Revisa fotos del trabajo con listas, defectos, severidad e informes.';

  @override
  String get toolMultiLocationTitle => 'Panel multiubicación';

  @override
  String get toolMultiLocationSubtitle =>
      'Controla ingresos, trabajos activos, equipos, facturas sin pagar y conversión de leads.';

  @override
  String get toolSubMarketplaceTitle => 'Mercado de subcontratistas';

  @override
  String get toolSubMarketplaceSubtitle =>
      'Publica trabajo sobrante, compara ofertas, verifica subs y transfiere trabajos.';

  @override
  String get toolBidAnalyzerTitle => 'Analizador de cotizaciones con IA';

  @override
  String get toolBidAnalyzerSubtitle =>
      'Extrae partidas, mide riesgo de margen y genera contraofertas.';

  @override
  String get toolSelectServiceType => 'Seleccionar tipo de servicio';

  @override
  String get toolActionUnlock => 'Desbloquear';

  @override
  String get toolActionAnalyzeBid => 'Analizar cotización';

  @override
  String get toolActionPostJob => 'Publicar trabajo';

  @override
  String get toolActionPriceJob => 'Poner precio';

  @override
  String get toolActionEstimateCost => 'Estimar costo';

  @override
  String get toolActionReviewEstimates => 'Revisar presupuestos';

  @override
  String get toolActionCreateInvoice => 'Crear factura';

  @override
  String get toolActionTrackInvoices => 'Ver facturas';

  @override
  String get toolActionBuildSchedule => 'Crear agenda';

  @override
  String get toolActionInspectPhotos => 'Inspeccionar fotos';

  @override
  String get toolActionCreateRender => 'Crear render';

  @override
  String get toolActionOpenGallery => 'Abrir galería';

  @override
  String get toolActionReviewLocations => 'Revisar ubicaciones';

  @override
  String get toolMetricRiskScore => 'Riesgo';

  @override
  String get toolMetricVerifiedSubs => 'Subs verificados';

  @override
  String get toolMetricMarginReady => 'Margen listo';

  @override
  String get toolMetricRevisionHistory => 'Historial';

  @override
  String get toolMetricQuoteReady => 'Cotización lista';

  @override
  String get toolMetricPaymentLink => 'Enlace de pago';

  @override
  String get toolMetricOverdueBadges => 'Vencidas';

  @override
  String get toolMetricConflictWarnings => 'Conflictos';

  @override
  String get toolMetricReportPdf => 'Informe PDF';

  @override
  String get toolMetricClientShare => 'Compartir con cliente';

  @override
  String get toolMetricFolders => 'Carpetas';

  @override
  String get toolMetricOwnerSummary => 'Resumen del dueño';

  @override
  String get email => 'Correo electrónico';

  @override
  String get phone => 'Teléfono';

  @override
  String get address => 'Dirección';

  @override
  String get update => 'Actualizar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Eliminar';

  @override
  String get history => 'Historial';

  @override
  String get description => 'Descripción';

  @override
  String get item => 'Partida';

  @override
  String get copyToClipboard => 'Copiar al portapapeles';

  @override
  String get copiedToClipboard => 'Copiado al portapapeles';

  @override
  String get clientDirectoryTitle => 'Directorio de clientes';

  @override
  String get clientDirectorySelect => 'Seleccionar cliente';

  @override
  String get clientDirectorySignInRequired =>
      'Inicia sesión para ver clientes.';

  @override
  String get clientDirectorySearchHint => 'Buscar clientes...';

  @override
  String get clientDirectoryAddClient => 'Agregar cliente';

  @override
  String get clientDirectoryNoClients => 'Aún no hay clientes';

  @override
  String get clientDirectoryNoMatches => 'Sin resultados';

  @override
  String get clientDirectoryNoClientsSubtitle =>
      'Toca + para agregar tu primer cliente';

  @override
  String get clientDirectoryNoMatchesSubtitle => 'Intenta otra búsqueda';

  @override
  String get clientDirectoryNewClient => 'Nuevo cliente';

  @override
  String get clientDirectoryEditClient => 'Editar cliente';

  @override
  String get clientDirectoryNameLabel => 'Nombre del cliente *';

  @override
  String get clientDirectoryNotesLabel => 'Notas';

  @override
  String get clientDirectorySaveClient => 'Guardar cliente';

  @override
  String get clientDirectoryNameRequired => 'El nombre es obligatorio';

  @override
  String get clientDirectoryDeleteTitle => '¿Eliminar cliente?';

  @override
  String clientDirectoryDeleteMessage(String clientName) {
    return '¿Quitar a \"$clientName\" de tu directorio?';
  }

  @override
  String get bidAnalyzerAnalyzeTab => 'Analizar';

  @override
  String get bidAnalyzerPasteRequired =>
      'Pega primero una cotización de competidor o texto de RFP';

  @override
  String get bidAnalyzerJobLabel => 'Etiqueta del trabajo/proyecto (opcional)';

  @override
  String get bidAnalyzerJobHint => 'Ej. Exterior 5000 pies² - Casa Smith';

  @override
  String get bidAnalyzerInputTitle => 'Cotización competidora / texto de RFP';

  @override
  String get bidAnalyzerPasteClipboard => 'Pegar del portapapeles';

  @override
  String get bidAnalyzerInputSubtitle =>
      'Pega el documento completo, correo o desglose por partidas';

  @override
  String get bidAnalyzerInputHint =>
      'Pega aquí el texto de la cotización competidora...\n\nEjemplo:\n- Pintura interior (3 hab.): \$2,400\n- Molduras y zócalos: \$800\n- Techo: \$600\n- Preparación y primer: \$500';

  @override
  String bidAnalyzerCharacters(int count) {
    return '$count caracteres';
  }

  @override
  String get bidAnalyzerAnalyzing => 'Analizando...';

  @override
  String get bidAnalyzerSummaryTitle => 'Resumen del análisis';

  @override
  String get bidAnalyzerTheirTotal => 'Total de ellos';

  @override
  String get bidAnalyzerYourPrice => 'Tu precio';

  @override
  String bidAnalyzerLineItems(int count) {
    return 'Partidas ($count)';
  }

  @override
  String get bidAnalyzerTheirs => 'Ellos';

  @override
  String get bidAnalyzerYours => 'Tú';

  @override
  String get bidAnalyzerCounterBidTitle => 'Contraoferta sugerida';

  @override
  String get bidAnalyzerCounterBidLabel => 'Sugerencia de contraoferta:';

  @override
  String get bidAnalyzerNoAnalyses => 'Aún no hay análisis';

  @override
  String get bidAnalyzerFallbackTitle => 'Análisis de cotización';

  @override
  String bidAnalyzerHistoryItems(String count) {
    return '$count partidas';
  }

  @override
  String bidAnalyzerLocalSummary(int count, String totalText) {
    return 'El análisis local extrajo $count partidas$totalText. Despliega la Cloud Function analyzeBid para comparación con IA contra tu motor de precios y sugerencias de contraoferta.';
  }

  @override
  String bidAnalyzerLocalSummaryTotal(String total) {
    return ' (total: $total)';
  }

  @override
  String get notNow => 'Ahora no';

  @override
  String get upgrade => 'Mejorar';

  @override
  String get signInRequired => 'Inicio de sesión requerido';

  @override
  String get checkConnectionTryAgain =>
      'Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get pullToRefreshTryAgain =>
      'Desliza para actualizar o inténtalo de nuevo en un momento.';

  @override
  String get service => 'Servicio';

  @override
  String get unknown => 'Desconocido';

  @override
  String get escrow => 'Escrow';

  @override
  String get approved => 'Aprobado';

  @override
  String get pendingAdminApproval => 'Pendiente de aprobación del admin';

  @override
  String get payoutsConnected => 'Cobros conectados';

  @override
  String get payoutsPending => 'Cobros pendientes';

  @override
  String get payoutsSetup => 'Configurar cobros';

  @override
  String get payoutsNotConnected => 'Cobros no conectados';

  @override
  String get accountOverview => 'Resumen de cuenta';

  @override
  String nonExclusiveCredits(int count) {
    return 'Créditos no exclusivos: $count';
  }

  @override
  String exclusiveCredits(int count) {
    return 'Créditos exclusivos: $count';
  }

  @override
  String get editProfile => 'Editar perfil';

  @override
  String get updatePublicContractorInfo =>
      'Actualiza tu información pública de contratista';

  @override
  String get getVerified => 'Verificarme';

  @override
  String get improveTrustWinMoreWork =>
      'Mejora la confianza y gana más trabajos';

  @override
  String get analytics => 'Analíticas';

  @override
  String get availability => 'Disponibilidad';

  @override
  String get serviceArea => 'Área de servicio';

  @override
  String get businessProfile => 'Perfil del negocio';

  @override
  String get qAndA => 'Preguntas y respuestas';

  @override
  String get contractorPortalWelcomeFallback => 'ahí';

  @override
  String get contractorPortalProRequiredTitle => 'Contractor Pro requerido';

  @override
  String get contractorPortalProRequiredBody =>
      'Desbloquea la Calculadora de precios, el Estimador de costos y la Herramienta de renders con Contractor Pro.';

  @override
  String get contractorPortalEnterpriseRequiredTitle =>
      'Plan Enterprise requerido';

  @override
  String get contractorPortalEnterpriseBoardBody =>
      'El tablero de subcontratistas está disponible en el plan Enterprise. Mejora tu plan para publicar y buscar trabajos subcontratados.';

  @override
  String get contractorPortalEnterpriseToolsBody =>
      'Mejora a Enterprise para operaciones multiubicación, mercado de subcontratistas, análisis de cotizaciones, programación de equipos e informes de calidad.';

  @override
  String get contractorPortalBrowseJobs => 'Buscar trabajos';

  @override
  String get contractorPortalFindNewLeads => 'Encuentra nuevos leads';

  @override
  String get contractorPortalReplyFaster => 'Responde más rápido';

  @override
  String get contractorPortalPortfolio => 'Portafolio';

  @override
  String get contractorPortalShowcaseYourWork => 'Muestra tu trabajo';

  @override
  String get contractorPortalPayments => 'Pagos';

  @override
  String get contractorPortalTrackEarnings => 'Controla tus ingresos';

  @override
  String get contractorPortalSubcontractJobs => 'Trabajos subcontratados';

  @override
  String get contractorPortalViewPostedWork => 'Ver trabajos publicados';

  @override
  String get contractorPortalPostJob => 'Publicar trabajo';

  @override
  String get contractorPortalShareOverflowWork => 'Comparte trabajo sobrante';

  @override
  String get contractorPortalCrewRoster => 'Equipo';

  @override
  String get contractorPortalManageTeam => 'Administra tu equipo';

  @override
  String get contractorPortalLeaderboard => 'Clasificación';

  @override
  String get contractorPortalXpRankings => 'Ranking de XP';

  @override
  String get contractorPortalProfitLoss => 'Pérdidas y ganancias';

  @override
  String get contractorPortalFinancialDashboard => 'Panel financiero';

  @override
  String get contractorPortalAiSupport => 'Soporte con IA';

  @override
  String get contractorPortalInstantHelp => 'Ayuda instantánea 24/7';

  @override
  String get contractorPortalNoClaimedJobs =>
      'Aún no tienes trabajos reclamados';

  @override
  String get contractorPortalNoClaimedJobsSubtitle =>
      'Busca leads y compra uno para iniciar una conversación con el cliente.';

  @override
  String get contractorPortalCouldNotLoadJobs =>
      'No se pudieron cargar los trabajos';

  @override
  String contractorPortalLocationLabel(String location) {
    return 'Ubicación: $location';
  }

  @override
  String contractorPortalClaimedLabel(String date) {
    return 'Reclamado: $date';
  }

  @override
  String contractorPortalCreatedLabel(String date) {
    return 'Creado: $date';
  }

  @override
  String get contractorPortalJobsSubtitle =>
      'Busca y compra leads de proyectos de clientes';

  @override
  String get contractorPortalMyClaimedJobs => 'Mis trabajos reclamados';

  @override
  String get contractorPortalPlanSubtitle =>
      'Administra tu cuenta, créditos y suscripción';

  @override
  String get contractorPortalCouldNotLoadAccount =>
      'No se pudo cargar la información de la cuenta';

  @override
  String get contractorPortalTrackPerformance =>
      'Mide rendimiento y crecimiento';

  @override
  String get keepScheduleUpToDate => 'Mantén tu calendario actualizado';

  @override
  String get controlWhereYouGetLeads => 'Controla dónde recibes leads';

  @override
  String get showcaseBestWork => 'Muestra tus mejores trabajos';

  @override
  String get manageCompanyDetails => 'Administra los datos de la empresa';

  @override
  String get answerCustomerQuestions =>
      'Responde preguntas comunes de clientes';

  @override
  String get adminOperationsTitle => 'Operaciones admin';

  @override
  String get adminOverviewTab => 'Resumen';

  @override
  String get adminPaymentsTab => 'Pagos';

  @override
  String get adminDisputesTab => 'Disputas';

  @override
  String get adminModerationTab => 'Moderación';

  @override
  String adminCheckFailed(String error) {
    return 'Falló la verificación admin: $error';
  }

  @override
  String get adminAccessRequired =>
      'Se requiere acceso admin. Esta pantalla solo está disponible para operadores aprobados.';

  @override
  String disputeStatusUpdated(String status) {
    return 'Estado de disputa actualizado a $status';
  }

  @override
  String errorWithMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get resolveDispute => 'Resolver disputa';

  @override
  String get resolutionDetails => 'Detalles de resolución';

  @override
  String get resolve => 'Resolver';

  @override
  String errorLoadingDisputes(String error) {
    return 'Error al cargar disputas:\n\n$error';
  }

  @override
  String get noActiveDisputes => 'No hay disputas activas';

  @override
  String get filtersAndSorting => 'Filtros y orden';

  @override
  String get open => 'Abierta';

  @override
  String get underReview => 'En revisión';

  @override
  String get resolved => 'Resuelta';

  @override
  String get closed => 'Cerrada';

  @override
  String get all => 'Todo';

  @override
  String get sortBy => 'Ordenar por';

  @override
  String get newestToOldest => 'Más reciente a más antiguo';

  @override
  String get oldestToNewest => 'Más antiguo a más reciente';

  @override
  String get details => 'Detalles';

  @override
  String jobIdLabel(String jobId) {
    return 'ID del trabajo: $jobId';
  }

  @override
  String get startReview => 'Iniciar revisión';

  @override
  String get close => 'Cerrar';

  @override
  String get disputeClosedWithoutResolution => 'Disputa cerrada sin resolución';

  @override
  String get paymentOpsEscrowOperations => 'Operaciones de escrow';

  @override
  String get paymentOpsEscrowOperationsSubtitle =>
      'Estados atascados, fallidos, reembolsos, disputas y pagos.';

  @override
  String get paymentOpsNoEscrowIssues => 'Sin problemas de escrow';

  @override
  String get paymentOpsNoEscrowIssuesSubtitle =>
      'Los registros de escrow no requieren atención admin.';

  @override
  String get paymentOpsPaymentRecords => 'Registros de pago';

  @override
  String get paymentOpsPaymentRecordsSubtitle =>
      'Registros de Stripe, tienda, créditos de leads y facturas.';

  @override
  String get paymentOpsNoPaymentIssues => 'Sin problemas de pago';

  @override
  String get paymentOpsNoPaymentIssuesSubtitle =>
      'Los registros de pago no requieren atención.';

  @override
  String get paymentOpsPayoutSetup => 'Configuración de cobros';

  @override
  String get paymentOpsPayoutSetupSubtitle =>
      'Contratistas que aún no pueden recibir cobros de forma confiable.';

  @override
  String get paymentOpsPayoutsReady =>
      'Todas las configuraciones de cobro se ven listas';

  @override
  String get paymentOpsPayoutsReadySubtitle =>
      'No se encontraron bloqueos de cobro para contratistas.';

  @override
  String get needsAttention => 'Requiere atención';

  @override
  String get ok => 'OK';

  @override
  String escrowIdLabel(String id) {
    return 'Escrow: $id';
  }

  @override
  String jobLabel(String jobId) {
    return 'Trabajo: $jobId';
  }

  @override
  String statusPayoutLabel(String status, String payout) {
    return 'Estado: $status • Cobro: $payout';
  }

  @override
  String amountContractorPayoutLabel(String amount, String payout) {
    return 'Monto: $amount • Cobro del contratista: $payout';
  }

  @override
  String get openEscrow => 'Abrir escrow';

  @override
  String get openJob => 'Abrir trabajo';

  @override
  String get markReviewed => 'Marcar revisado';

  @override
  String idLabel(String id) {
    return 'ID: $id';
  }

  @override
  String typeLabel(String type) {
    return 'Tipo: $type';
  }

  @override
  String userLabel(String userId) {
    return 'Usuario: $userId';
  }

  @override
  String statusLabel(String status) {
    return 'Estado: $status';
  }

  @override
  String amountLabel(String amount) {
    return 'Monto: $amount';
  }

  @override
  String get check => 'Revisar';

  @override
  String stripeAccountLabel(String account) {
    return 'Cuenta Stripe: $account';
  }

  @override
  String detailsSubmittedLabel(String value) {
    return 'Datos enviados: $value';
  }

  @override
  String payoutsEnabledLabel(String value) {
    return 'Cobros activados: $value';
  }

  @override
  String get missing => 'Faltante';

  @override
  String get yes => 'sí';

  @override
  String get no => 'no';

  @override
  String get escrowMarkedReviewed => 'Escrow marcado como revisado.';

  @override
  String couldNotMarkReviewed(String error) {
    return 'No se pudo marcar como revisado: $error';
  }

  @override
  String get escrows => 'Escrows';

  @override
  String get escrowAlerts => 'Alertas de escrow';

  @override
  String get paymentAlerts => 'Alertas de pago';

  @override
  String get allRecords => 'Todos los registros';

  @override
  String errorLoadingPaymentOperations(String message) {
    return 'Error al cargar operaciones de pago:\n\n$message';
  }

  @override
  String get boostListingTitle => 'Impulsar perfil';

  @override
  String get boostListingSubtitle =>
      'Aparece primero en los resultados de búsqueda';

  @override
  String get retry => 'Reintentar';
}
