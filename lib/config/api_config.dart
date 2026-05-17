class ApiConfig {
  static const String baseUrl = 'http://10.0.2.2:5000';

  static const Duration timeout = Duration(seconds: 15);

  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
  };

  static Map<String, String> authHeaders(String token) => {
    'Content-Type':  'application/json',
    'Authorization': 'Bearer $token',
  };
  // ── Map / Routing ──────────────────────────────────────────────────────────
  static const String osrmBase         = 'https://router.project-osrm.org/route/v1/driving';
  static const String osrmNearest      = 'https://router.project-osrm.org/nearest/v1/driving';
  static const String nominatimSearch  = 'https://nominatim.openstreetmap.org/search';
  static const String nominatimReverse = 'https://nominatim.openstreetmap.org/reverse';
  static const String photonSearch     = 'https://photon.komoot.io/api/';
  static const String photonReverse    = 'https://photon.komoot.io/reverse/';
  // ── Auth ───────────────────────────────────────────────────────────────────
  static const String login    = '$baseUrl/api/auth/login';
  static const String register = '$baseUrl/api/auth/register';
  static const String me       = '$baseUrl/api/auth/me';

  // ── Students / Enrollments ─────────────────────────────────────────────────
  static const String students    = '$baseUrl/api/students';
  static const String apply       = '$baseUrl/api/apply';
  static const String enrollments = '$baseUrl/api/enrollments/my';
  static const String enrollmentAgreement       = '$baseUrl/api/enrollment-agreement/my';
  static const String enrollmentAgreementSubmit = '$baseUrl/api/enrollment-agreement/my/submit';

  // ── Documents ─────────────────────────────────────────────────────────────
  static const String documents    = '$baseUrl/api/documents';
  static String documentUpload     = '$baseUrl/api/documents/upload';
  static String documentDelete(String id) => '$baseUrl/api/documents/$id';

  // ── Messaging ─────────────────────────────────────────────────────────────
  static const String conversations     = '$baseUrl/api/conversations';
  static const String availableContacts = '$baseUrl/api/conversations/available-contacts';
  static String conversationRead(String id) => '$baseUrl/api/conversations/$id/read';
  static String messages(String convId)     => '$baseUrl/api/messages/$convId';
  static String messageDelete(String id)    => '$baseUrl/api/messages/$id';
  static const String unreadCount          = '$baseUrl/api/messages/unread/count';

  // ── Socket.io (no /api suffix) ────────────────────────────────────────────
  static const String socketUrl = baseUrl;
static const String tomTomKey = '83SaKCaOjYlAcOAtQ8tuc8Am7qgZ7vGd';

  // ── Quiz / Study Guide ────────────────────────────────────────────────────
  static const String quizSections   = '$baseUrl/api/quiz/sections';
  static const String quizProgress   = '$baseUrl/api/quiz/my-progress';
  static String quizQuestions(String sectionId) =>
      '$baseUrl/api/quiz/sections/$sectionId/questions';
  static String quizAttempt(String sectionId) =>
      '$baseUrl/api/quiz/sections/$sectionId/attempt';

  // ── Announcements ─────────────────────────────────────────────────────────
  static const String announcements         = '$baseUrl/api/announcements';
  static String announcementRead(String id)  => '$baseUrl/api/announcements/$id/read';
  static const String announcementsReadAll  = '$baseUrl/api/announcements/read-all';

  // ── Support / Help Center ─────────────────────────────────────────────────
  static const String supportMessages = '$baseUrl/api/support/messages';
  static const String supportTickets  = '$baseUrl/api/support/tickets';
  static String supportMessagesForUser(String userId) =>
      '$baseUrl/api/support/messages?userId=${Uri.encodeComponent(userId)}';
  static String supportTicketsForUser(String userId) =>
      '$baseUrl/api/support/tickets?userId=${Uri.encodeComponent(userId)}';

      // ── Study Materials ───────────────────────────────────────────────────────
static const String studyMaterials = '$baseUrl/api/study-materials';

static String resolveFileUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  final String resolved;
  if (path.startsWith('http://') || path.startsWith('https://')) {
    resolved = path;
  } else {
    resolved = '$baseUrl${path.startsWith('/') ? '' : '/'}$path';
  }
  return rewriteGoogleDriveUrl(resolved);
}

/// Converts any Google Drive sharing/preview URL → direct download URL.
/// /file/d/{ID}/view|preview  →  uc?export=download&id={ID}
/// /open?id={ID}              →  uc?export=download&id={ID}
static String rewriteGoogleDriveUrl(String url) {
  final fileMatch = RegExp(
    r'https://drive\.google\.com/file/d/([^/?#]+)',
  ).firstMatch(url);
  if (fileMatch != null) {
    return 'https://drive.google.com/uc?export=download&id=${fileMatch.group(1)}';
  }

  final openMatch = RegExp(
    r'https://drive\.google\.com/open\?id=([^&]+)',
  ).firstMatch(url);
  if (openMatch != null) {
    return 'https://drive.google.com/uc?export=download&id=${openMatch.group(1)}';
  }

  return url;
}


}