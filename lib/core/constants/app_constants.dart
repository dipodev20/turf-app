const String supabaseUrl = 'https://klaxbmnbyrxvvaevkxze.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtsYXhibW5ieXJ4dnZhZXZreHplIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA4Mzc5NjEsImV4cCI6MjA5NjQxMzk2MX0.ZaME_vUEBcL37y2xI_KwcHIH4rSAWHK-i8AqV6cXb08';
const String stadiaMapsKey = '1842b3ca-dde4-4c1b-969d-0d07ed46f814';
const String tileUrlTemplate = 'https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}{r}.png?api_key=$stadiaMapsKey';

// Speed thresholds (km/h)
const double maxWalkSpeed = 6.0;
const double maxCycleSpeed = 20.0;

// Territory
const double captureRadiusMeters = 50.0;
const int minPointsForCapture = 4;

// Season
const String currentSeason = 'Season III';

// App
const String appName = 'TURF';
const String appVersion = '1.0.0';
