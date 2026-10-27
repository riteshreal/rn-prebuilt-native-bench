# Sourced by run-ci.sh:  source config.sh <mmkv|vc>   ->  APP_DIR, LIBS
# LIBS = the Gradle projects that get prebuilt (the three repos' own Android modules).
case "$1" in
  mmkv)
    APP_DIR="$ROOT/repos/mmkv/example"
    LIBS="react-native-nitro-modules,react-native-mmkv"
    ;;
  vc)
    APP_DIR="$ROOT/repos/vision-camera/apps/simple-camera"
    LIBS="react-native-nitro-modules,react-native-vision-camera,react-native-vision-camera-barcode-scanner,react-native-vision-camera-location,react-native-vision-camera-resizer,react-native-vision-camera-worklets"
    ;;
  *) echo "unknown app: $1" >&2; exit 2 ;;
esac
