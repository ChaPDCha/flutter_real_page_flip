//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <real_page_flip/real_page_flip_linux.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) real_page_flip_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "RealPageFlipLinux");
  real_page_flip_linux_register_with_registrar(real_page_flip_registrar);
}
