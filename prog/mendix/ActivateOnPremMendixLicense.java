import java.util.Objects;
import java.util.prefs.Preferences;

public class ActivateOnPremMendixLicense {

    public static void main(final String[] args) {
        final String license_id = getEnv("LICENSE_ID");
        final String license_key = getEnv("LICENSE_KEY");

        final Preferences prefs = java.util.prefs.Preferences.userRoot().node("com/mendix/core");

        final String key = "id";
        printOldPref(prefs, key);
        final String key2 = "license_key";
        printOldPref(prefs, key2);

        prefs.put(key, license_id);
        prefs.put(key2, license_key);
    }

    private static void printOldPref(final Preferences prefs, final String key) {
        System.out.println("old " + key + ": " + prefs.get(key, null));
    }

    private static String getEnv(final String string) {
        return Objects.requireNonNull(System.getenv(string));
    }

}
