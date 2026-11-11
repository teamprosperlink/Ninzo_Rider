import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/validators.dart';
import '../../../injection_container.dart';
import '../../auth/providers/auth_state_providers.dart';
import '../../../domain/entities/register_failure.dart';
import '../../../domain/entities/rider_application.dart';
import '../../../domain/entities/rider_area.dart';
import '../../../domain/entities/rider_document.dart';
import '../providers/registration_provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_mode.dart';
import '../../intro/viewmodels/intro_flow_view_model.dart';

/// The register screens. Several Figma frames are states of one screen:
///
/// * [details]: Register 01 (empty), 02 (filled), 03 (number already registered)
/// * [area]: Register 14 (search your area), 15 (results), 16 (no results)
/// * [documents]: Register 04 (none added), 07 (complete)
/// * [photo]: Register 05 (take photo)
/// * [review]: Register 06 (photo review)
/// * [status]: Register 08–13, from the application's [RegistrationStatus]
enum RegisterScreen { details, area, documents, photo, review, status }

/// The Register 03 state of the details screen.
enum RegisterIssue { alreadyRegistered }

class RegisterState {
  const RegisterState({
    this.name = '',
    this.phone = '',
    this.area,
    this.page,
    this.busy = false,
    this.issue,
    this.query = '',
    this.results = const [],
    this.searching = false,
    this.locating = false,
    this.photoDocument,
    this.photoSide = 0,
    this.photoPath,
    this.showSpot = false,
  });

  /// Full name typed on Register 01.
  final String name;

  /// 10 digits after +91.
  final String phone;
  final RiderArea? area;

  /// Screen the rider moved to; null shows the default for the application.
  final RegisterScreen? page;

  /// Saving, signing in, uploading or submitting.
  final bool busy;
  final RegisterIssue? issue;

  /// Area search text (Register 14–16) and its results.
  final String query;
  final List<RiderArea> results;
  final bool searching;

  /// Finding the area from the phone's location.
  final bool locating;

  /// Document and side (index into [RiderDocument.sides]) being photographed.
  final RiderDocument? photoDocument;
  final int photoSide;

  /// Photo taken, shown on Register 06.
  final String? photoPath;

  /// "Sign in" tapped on Register 09: show the spot (Register 10).
  final bool showSpot;

  bool get detailsComplete =>
      name.trim().isNotEmpty && Validators.isMobile(phone) && area != null;

  DocumentSide? get side => photoDocument?.sides[photoSide];

  RegisterState copyWith({
    String? name,
    String? phone,
    RiderArea? area,
    RegisterScreen? Function()? page,
    bool? busy,
    RegisterIssue? Function()? issue,
    String? query,
    List<RiderArea>? results,
    bool? searching,
    bool? locating,
    RiderDocument? photoDocument,
    int? photoSide,
    String? Function()? photoPath,
    bool? showSpot,
  }) => RegisterState(
    name: name ?? this.name,
    phone: phone ?? this.phone,
    area: area ?? this.area,
    page: page == null ? this.page : page(),
    busy: busy ?? this.busy,
    issue: issue == null ? this.issue : issue(),
    query: query ?? this.query,
    results: results ?? this.results,
    searching: searching ?? this.searching,
    locating: locating ?? this.locating,
    photoDocument: photoDocument ?? this.photoDocument,
    photoSide: photoSide ?? this.photoSide,
    photoPath: photoPath == null ? this.photoPath : photoPath(),
    showSpot: showSpot ?? this.showSpot,
  );
}

/// Register 01–16. "Continue" signs the new rider in (no code); then the
/// details are saved and the rider adds documents.
class RegisterViewModel extends Notifier<RegisterState> {
  @override
  RegisterState build() {
    // Signed in without an application (just pressed "Continue"): save the
    // details typed before; then open the documents.
    ref.listen(
      registrationProvider,
      (previous, next) => _onApplication(next, previous?.value),
    );
    Future.microtask(() {
      if (ref.mounted) _onApplication(ref.read(registrationProvider), null);
    });
    ref.listen(currentUidProvider, (previous, uid) {
      if (uid == null && previous != null) {
        state = RegisterState(
          name: state.name,
          phone: state.phone,
          area: state.area,
        );
      }
      final phone = _authPhone;
      if (uid != null && phone != null) {
        state = state.copyWith(phone: _digits(phone));
      }
    });
    final phone = _authPhone;
    return RegisterState(phone: phone == null ? '' : _digits(phone));
  }

  void _onApplication(
    AsyncValue<RiderApplication?> next,
    RiderApplication? previous,
  ) {
    if (!next.hasValue) return;
    final application = next.value;
    if (application == null) {
      if (signedIn && state.detailsComplete && !state.busy) saveDetails();
    } else if (previous == null) {
      _prefill(application);
    }
  }

  /// The signed-in number; null for a new rider, who signs in without one.
  String? get _authPhone {
    final phone = ref.read(authStateProvider).value?.phone;
    return phone == null || phone.isEmpty ? null : phone;
  }

  static String _digits(String e164) =>
      e164.startsWith(AppStrings.indiaDialCode) ? e164.substring(AppStrings.indiaDialCode.length) : e164;

  void _prefill(RiderApplication a) {
    state = state.copyWith(
      name: state.name.isEmpty ? a.name : null,
      phone: _digits(a.phone),
      area: state.area ?? (a.area.name.isEmpty ? null : a.area),
    );
  }

  RiderApplication? get _application => ref.read(registrationProvider).value;
  bool get signedIn => ref.read(currentUidProvider) != null;

  /// Which screen shows for [application].
  RegisterScreen screenFor(RiderApplication? application) {
    final page = state.page;
    if (application == null) {
      return page == RegisterScreen.area
          ? RegisterScreen.area
          : RegisterScreen.details;
    }
    if (application.status != RegistrationStatus.draft) {
      return RegisterScreen.status;
    }
    return page ?? RegisterScreen.documents;
  }

  // ── Register 01–03 ──

  void setName(String name) => state = state.copyWith(name: name);

  void setPhone(String digits) {
    if (digits == state.phone) return;
    state = state.copyWith(phone: digits, issue: () => null);
  }

  /// "Continue": signed out, check the number and sign in (the details save
  /// next); signed in, save the details.
  Future<void> continueDetails() async {
    if (!state.detailsComplete || state.busy) return;
    if (signedIn) return saveDetails();
    // The rider API signs in only with an OTP: Login's code screen, then
    // back here, where the details save once the application loads.
    if (kRiderApi) {
      ref.read(introFlowProvider.notifier).verifyNumber(state.phone);
      return;
    }
    state = state.copyWith(busy: true, issue: () => null);
    try {
      await ref.read(startRegistrationUseCaseProvider)(state.phone);
      if (!ref.mounted) return;
      state = state.copyWith(busy: false);
      await ref.read(verifyOtpUseCaseProvider).signedIn(keepSignedIn: true);
      // The (empty) application loaded while busy signing in; otherwise
      // the listener saves once it loads.
      if (ref.mounted) _onApplication(ref.read(registrationProvider), null);
    } on RegisterFailure catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        busy: false,
        issue: e.kind == RegisterFailureKind.alreadyRegistered ? () => RegisterIssue.alreadyRegistered : null,
      );
    } on Object catch (_) {
      if (ref.mounted) {
        state = state.copyWith(busy: false);
      }
    }
  }

  /// Saves the details of the signed-in rider; the documents open next.
  Future<void> saveDetails() async {
    final uid = ref.read(currentUidProvider);
    final phone = _authPhone ?? AppStrings.indiaPhone(state.phone);
    if (uid == null) return;
    state = state.copyWith(busy: true);
    try {
      await ref.read(saveRegistrationDetailsUseCaseProvider)(
        uid: uid,
        phone: phone,
        name: state.name,
        area: state.area,
      );
      if (ref.mounted) {
        state = state.copyWith(
          busy: false,
          page: () => RegisterScreen.documents,
        );
      }
    } on Object catch (_) {
      if (ref.mounted) {
        state = state.copyWith(busy: false);
      }
    }
  }

  /// Back arrow on Register 01 while signed in: leave registration.
  Future<void> signOut() => ref.read(signOutUseCaseProvider)();

  // ── Register 14–16 ──

  /// Tap on "Your area".
  Future<void> openArea() async {
    state = state.copyWith(
      page: () => RegisterScreen.area,
      query: '',
      results: const [],
    );
    await search('');
  }

  void closeArea() =>
      state = state.copyWith(page: () => RegisterScreen.details);

  Future<void> search(String query) async {
    state = state.copyWith(query: query, searching: true);
    try {
      final results = await ref.read(searchAreasUseCaseProvider)(query);
      if (ref.mounted && state.query == query) {
        state = state.copyWith(results: results, searching: false);
      }
    } on Object catch (_) {
      if (ref.mounted) {
        state = state.copyWith(searching: false);
      }
    }
  }

  Future<void> selectArea(RiderArea area) async {
    state = state.copyWith(area: area, page: () => RegisterScreen.details);
    if (area.latitude != null) return;
    try {
      final resolved = await ref.read(resolveAreaUseCaseProvider)(area);
      if (ref.mounted && state.area == area) state = state.copyWith(area: resolved);
    } on Object catch (_) {
      // The rider keeps the picked name; only its coordinates are missing.
    }
  }

  /// "Use my current location".
  Future<void> useCurrentLocation() async {
    if (state.locating) return;
    state = state.copyWith(locating: true);
    try {
      final area = await ref.read(findAreaNearMeUseCaseProvider)();
      if (ref.mounted) {
        state = state.copyWith(
          locating: false,
          area: area,
          page: () => RegisterScreen.details,
        );
      }
    } on Object catch (_) {
      if (ref.mounted) {
        state = state.copyWith(locating: false);
      }
    }
  }

  // ── Register 04–07 ──

  /// Documents back arrow: edit the details.
  void editDetails() =>
      state = state.copyWith(page: () => RegisterScreen.details);

  /// "Add" on a document: photograph its first side.
  void addDocument(RiderDocument document) => state = state.copyWith(
    page: () => RegisterScreen.photo,
    photoDocument: document,
    photoSide: 0,
    photoPath: () => null,
  );

  void backToDocuments() =>
      state = state.copyWith(page: () => null, photoPath: () => null);

  /// "Take photo" / "Upload from gallery".
  Future<void> takePhoto({bool fromGallery = false}) async {
    final document = state.photoDocument;
    if (document == null || state.busy) return;
    try {
      final path = await ref.read(takeDocumentPhotoUseCaseProvider)(
        document,
        fromGallery: fromGallery,
      );
      if (path == null || !ref.mounted) return;
      state = state.copyWith(
        page: () => RegisterScreen.review,
        photoPath: () => path,
      );
    } on Object catch (_) {
      // No frame for this: the screen stays as it was.
    }
  }

  /// "Retake" on Register 06.
  void retake() => state = state.copyWith(
    page: () => RegisterScreen.photo,
    photoPath: () => null,
  );

  /// "Use this photo": upload it, then the next side or back to the list.
  Future<void> usePhoto() async {
    final application = _application;
    final document = state.photoDocument;
    final side = state.side;
    final path = state.photoPath;
    if (application == null ||
        document == null ||
        side == null ||
        path == null ||
        state.busy) {
      return;
    }
    state = state.copyWith(busy: true);
    try {
      await ref.read(uploadDocumentPhotoUseCaseProvider)(
        application,
        document: document,
        side: side,
        filePath: path,
      );
      if (!ref.mounted) return;
      final next = state.photoSide + 1;
      state = next < document.sides.length
          ? state.copyWith(
              busy: false,
              page: () => RegisterScreen.photo,
              photoSide: next,
              photoPath: () => null,
            )
          : state.copyWith(
              busy: false,
              page: () => null,
              photoPath: () => null,
            );
    } on Object catch (_) {
      if (ref.mounted) {
        state = state.copyWith(busy: false);
      }
    }
  }

  /// "Submit for review".
  /// Register 08 "Done": asks for the review result again.
  void checkReview() => ref.invalidate(registrationProvider);

  Future<void> submit() async {
    final application = _application;
    if (application == null || state.busy) return;
    state = state.copyWith(busy: true);
    try {
      await ref.read(submitForReviewUseCaseProvider)(application);
      if (ref.mounted) state = state.copyWith(busy: false, page: () => null);
    } on Object catch (_) {
      if (ref.mounted) {
        state = state.copyWith(busy: false);
      }
    }
  }

  // ── Register 08–13 ──

  /// "Retake driving licence" (11), "Upload documents by hand" (12),
  /// "Update driving licence" (13): reopen the application on the documents,
  /// or straight on the camera for one [document].
  Future<void> fix({RiderDocument? document}) async {
    final application = _application;
    if (application == null || state.busy) return;
    state = document == null
        ? state.copyWith(page: () => null, photoPath: () => null)
        : state.copyWith(
            page: () => RegisterScreen.photo,
            photoDocument: document,
            photoSide: 0,
            photoPath: () => null,
          );
    state = state.copyWith(busy: true);
    try {
      await ref.read(reopenApplicationUseCaseProvider)(application);
      if (ref.mounted) state = state.copyWith(busy: false);
    } on Object catch (_) {
      if (ref.mounted) {
        state = state.copyWith(busy: false);
      }
    }
  }

  /// "Sign in" on Register 09: show the spot.
  void showSpot() => state = state.copyWith(showSpot: true);

  /// "Got it" on Register 10: on to Home.
  Future<void> finish() async {
    final application = _application;
    if (application == null || state.busy) return;
    state = state.copyWith(busy: true);
    try {
      await ref.read(acknowledgeApprovalUseCaseProvider)(application);
      if (ref.mounted) state = state.copyWith(busy: false);
    } on Object catch (_) {
      if (ref.mounted) {
        state = state.copyWith(busy: false);
      }
    }
  }
}

final registerViewModelProvider =
    NotifierProvider<RegisterViewModel, RegisterState>(RegisterViewModel.new);
