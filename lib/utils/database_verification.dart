import 'package:danielshotsync/config/supabase_config.dart';

/// Helper class untuk verify database schema
class DatabaseVerification {
  /// Cek apakah kolom project_administrator ada di table projects
  static Future<bool> checkProjectAdministratorColumn() async {
    try {
      // Try to query with project_administrator field
      await SupabaseConfig.client
          .from('projects')
          .select('id, project_administrator')
          .limit(1);

      // If no error, column exists
      print('✅ Database OK - Column project_administrator exists');
      return true;
    } catch (e) {
      print('❌ Database ERROR - Column project_administrator NOT FOUND!');
      print('Error: $e');
      print('');
      print('SOLUSI:');
      print('1. Buka Supabase SQL Editor');
      print('2. Jalankan query ini:');
      print('');
      print(
        "ALTER TABLE public.projects ADD COLUMN project_administrator uuid[] NOT NULL DEFAULT '{}';",
      );
      print(
        "UPDATE public.projects SET project_administrator = ARRAY[created_by];",
      );
      print('');
      return false;
    }
  }

  /// Test insert/update project dengan administrator
  static Future<void> testProjectAdministrator() async {
    try {
      print('\n🧪 Testing project_administrator column...\n');

      // Get current user
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) {
        print('❌ User not logged in');
        return;
      }

      // Try to query projects with administrator field
      final projects = await SupabaseConfig.client
          .from('projects')
          .select('id, title, created_by, project_administrator')
          .limit(3);

      print('✅ Query SUCCESS - Found ${projects.length} projects');

      for (var project in projects) {
        final admins = project['project_administrator'] as List?;
        print('  - ${project['title']}: ${admins?.length ?? 0} administrators');
        if (admins != null && admins.isNotEmpty) {
          print('    Admins: $admins');
        }
      }

      print('\n✅ Database schema is OK!\n');
    } catch (e) {
      print('\n❌ TEST FAILED!\n');
      print('Error: $e\n');

      if (e.toString().contains('column') ||
          e.toString().contains('project_administrator') ||
          e.toString().contains('does not exist')) {
        print(
          '🔧 DIAGNOSIS: Column project_administrator NOT FOUND in database!\n',
        );
        print('📋 SOLUTION:');
        print('1. Open Supabase SQL Editor');
        print('2. Run this migration:\n');
        print("   ALTER TABLE public.projects");
        print(
          "   ADD COLUMN project_administrator uuid[] NOT NULL DEFAULT '{}';",
        );
        print('');
        print("   UPDATE public.projects");
        print("   SET project_administrator = ARRAY[created_by];");
        print('');
        print("   CREATE INDEX idx_projects_project_administrator");
        print("   ON public.projects USING GIN (project_administrator);");
        print('\n3. Restart the app\n');
      }
    }
  }
}
