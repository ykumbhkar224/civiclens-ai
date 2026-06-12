class AppConstants {
  // Supabase table names
  static const tableReports = 'reports';
  static const tableAppreciations = 'appreciations';
  static const tableOfficials = 'public_officials';
  static const tableNotifications = 'notifications';
  static const tableFcmTokens = 'user_fcm_tokens';
  static const tableProfiles = 'profiles';

  // Storage buckets
  static const bucketCivicImages = 'civic-images';

  // Civic score multipliers
  static const scoreSubmitReport = 10;
  static const scoreReportResolved = 25;
  static const scoreGiveAppreciation = 5;
  static const scoreUpvote = 2;

  // Map defaults
  static const defaultMapZoom = 13.0;
  static const nearbyRadiusKm = 5.0;

  // Pagination
  static const pageSize = 20;
}
