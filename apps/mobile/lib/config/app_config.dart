enum Flavor { local, qa, production }

class AppConfig {
  static late Flavor flavor;
  static late String apiBaseUrl;

  static void initialize(Flavor f) {
    flavor = f;
    switch (f) {
      case Flavor.local:
        apiBaseUrl = 'http://localhost:8000';
      case Flavor.qa:
        apiBaseUrl = 'https://qa-api.portfiq.com';
      case Flavor.production:
        apiBaseUrl = 'https://api.portfiq.com';
    }
  }
}
