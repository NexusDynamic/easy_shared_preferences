#include "include/easy_shared_preferences/easy_shared_preferences_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "easy_shared_preferences_plugin.h"

void EasySharedPreferencesPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  easy_shared_preferences::EasySharedPreferencesPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
