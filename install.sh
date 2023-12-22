SKIPMOUNT=false
PROPFILE=true
POSTFSDATA=true
LATESTARTSERVICE=true
MINAPI=27
ui_print_title() {
  local msg="$1"
  local term_width
  term_width=$(getprop ro.product.max_width)

  local padding
  padding=$(((term_width - ${#msg}) / 2))

  printf "%-${padding}s%s\n" " " "$msg"
}

print_modname() {
  MODNAME=$(grep_prop name $TMPDIR/module.prop)
  MODVER=$(grep_prop version $TMPDIR/module.prop)
  DV=$(grep_prop author $TMPDIR/module.prop)
  AndroidVersion=$(getprop ro.build.version.release)
  Device=$(getprop ro.product.device)
  Model=$(getprop ro.product.model)
  Brand=$(getprop ro.product.brand)
  # Mensaje a mostrar
  message="MULCH WEBVIEW"

  # Imprimir mensaje centrado en pantalla
  ui_print "$message"
  sleep 0.1
  echo "-------------------------------------"
  echo -e "- Module：\c"
  echo "$MODNAME"
  sleep 0.1
  echo -e "- Version：\c"
  echo "$MODVER"
  sleep 0.1
  echo -e "- Author：\c"
  echo "$DV"
  sleep 0.1
  echo -e "- Android \c"
  echo "$AndroidVersion"
  sleep 0.1
  #  echo -e "- Kernel：\c"
  #  echo "$(uname -r)"
  sleep 0.1
  echo -e "- Proveedor：\c"
  if [ "$BOOTMODE" ] && [ "$KSU" ]; then
    ui_print "KernelSU app"
    sed -i "s/^des.*/description= [😄 KernelSU cargado] Enable ${MODNAME} /g" $MODPATH/module.prop
    ui_print "- KernelSU：$KSU_KERNEL_VER_CODE (kernel) + $KSU_VER_CODE (ksud)"
    REMOVE="
/system/product/app/webview
/system/product/app/WebView
/system/product/app/WebViewGoogle
/system/product/app/WebViewGoogle64
/system/product/app/WebView64
/system/product/app/WebViewGoogle-Stub
 "
    if [ "$(which magisk)" ]; then
      ui_print "*********************************************************"
      ui_print "! ¡La implementación de múltiples root NO es compatible!"
      ui_print "! Por favor, desinstala Magisk antes de instalar Zygisksu"
      abort "*********************************************************"
    fi
  elif [ "$BOOTMODE" ] && [ "$MAGISK_VER_CODE" ]; then
    ui_print "Magisk app"
    sed -i "s/^des.*/description= [😄 Magisk cargado] Enable ${MODNAME} /g" $MODPATH/module.prop
    REPLACE="
/system/product/app/webview
/system/product/app/WebView
/system/product/app/WebViewGoogle
/system/product/app/WebViewGoogle64
/system/product/app/WebView64
/system/product/app/WebViewGoogle-Stub
 "
  else
    ui_print "*********************************************************"
    ui_print "Recovery no soportado"
    abort "*********************************************************"
  fi
  sleep 0.1
  echo "-------------------------------------"
  sleep 0.5
  echo "- Marca：$Brand"
  sleep 0.1
  echo "- Dispositivo：$Device"
  sleep 0.1
  echo "- Modelo：$Model"
  #  sleep 0.1
  #  echo "-------------------------------------"
  #  echo "- STORAGE："
  #  echo "- $(df -h /storage/emulated )"
  #  sleep 0.1
  #  echo "- RAM：$(free | grep Mem | awk '{print $2}')"
  sleep 0.5
  echo "-------------------------------------"
}

# Copy/extract your module files into $MODPATH in on_install.

on_install() {
  curl=$MODPATH/common/tools/$ARCH/curl
  [ -z $MINAPI ] || { [ $API -lt $MINAPI ] && abort "¡El API de tu sistema, $API, es inferior al API mínimo de $MINAPI! ¡Abortando!"; }
  # The following is the default implementation: extract $ZIPFILE/system to $MODPATH
  # Extend/change the logic to whatever you want
  getVersion() {
    VERSION=$(dumpsys package us.spotco.mulch_wv | grep -m1 versionName)
    VERSION="${VERSION#*=}" # Elimina el texto antes del signo igual (=)
  }
  # Crea un directorio para la aplicación Mulch Webview en MODPATH
  mkdir -p $MODPATH/system/product/app/MulchWebview
  # ui_print "- Extrayendo archivos"
  # unzip -o "$ZIPFILE" 'system/*' -d $MODPATH >&2
  VW_APK_URL=https://gitlab.com/divested-mobile/mulch/-/raw/master/prebuilt/${ARCH}/webview.apk


  # Descarga el archivo
  
  ui_print "- Descargando $MODNAME!"
  curl -skL "$VW_APK_URL" -o "$MODPATH/system/product/app/MulchWebview/webview.apk"
  # Comprueba si el archivo se descargó correctamente
  if [ ! -f "$MODPATH/system/product/app/MulchWebview/webview.apk" ]; then
    echo "- Error al descargar el archivo, sin Internet!"
    exit 1
  fi

  # Elimina los comentarios de los archivos y agrega una línea en blanco al final si no existe
  # Scripts
  for i in $(find $MODPATH -type f -name "*.sh" -o -name "*.prop" -o -name "*.rule"); do
    [ -f $i ] && {
      sed -i -e "/^#/d" -e "/^ *$/d" $i
      [ "$(tail -1 $i)" ] && echo "" >>$i
    } || continue
  done

  # Función para obtener la ruta base de la aplicación Mulch Webview
  basepath() {
    basepath=$(pm path us.spotco.mulch_wv | grep base)
    echo ${basepath#*:}
  }
  pm uninstall --user 0 com.google.android.webview >/dev/null 2>&1 &
  # Obtiene la versión de Mulch Webview
  getVersion
  if [ -z $(pm list packages us.spotco.mulch_wv | grep -v nga) ]; then
    ui_print "- Mulch Webview no está instalado!"
  else
    # Desmonta la aplicación Mulch Webview si está montada
    grep us.spotco.mulch_wv /proc/self/mountinfo | while read -r line; do
      ui_print "- Desmontando"
      mountpoint=$(echo "$line" | cut -d' ' -f5)
      umount -l "${mountpoint%%\\*}"
    done
  fi
  # Detiene la aplicación Mulch Webview
  am force-stop us.spotco.mulch_wv

  # Verifica si Mulch Webview está instalado y realiza acciones según el caso
  if BASEPATH=$(pm path us.spotco.mulch_wv); then
    BASEPATH=${BASEPATH##*:}
    BASEPATH=${BASEPATH%/*}
    if [ ${BASEPATH:1:6} = system ]; then
      ui_print "- Mulch Webview $VERSION es una aplicación del sistema"
    fi
  fi

  # Verifica si se necesita actualizar Mulch Webview con el archivo APK original
  if [ -n "$BASEPATH" ] && cmpr $BASEPATH $MODPATH/system/product/app/MulchWebview/webview.apk; then
    ui_print "- Mulch Webview $VERSION ya está actualizado!"
  else
    ui_print "- Instalando Mulch Webview"
    set_perm $MODPATH/system/product/app/MulchWebview/webview.apk 1000 1000 644 u:object_r:apk_data_file:s0
    if ! op=$(pm install --user 0 -i us.spotco.mulch_wv -r -d $MODPATH/system/product/app/MulchWebview/webview.apk 2>&1); then
      ui_print "- Error: la instalación de APK falló!"
      abort "${op}"
    else
      # Obtener la versión de Mulch Webview
      getVersion
      ui_print "- Mulch Webview $VERSION instalado!"
    fi

    # Obtener la nueva ruta de instalación de Mulch Webview
    BASEPATH=$(basepath)

    if [ -z "$BASEPATH" ]; then
      abort "${op}"
    fi
  fi
  # Verificar si Mulch Webview está instalado como App de sistema
  if [ -z $(pm list packages -s us.spotco.mulch_wv | grep -v nga) ]; then
    ui_print "- Mulch Webview no está instalado como una App de sistema!"
    if [ -f /data/adb/modules_update/system/product/app/MulchWebview/*.apk ]; then
      ui_print "- Estableciendo Mulch Webview $VERSION como App de sistema"
    fi
  fi
  # Establece los permisos para base.apk
  set_perm $MODPATH/base.apk 1000 1000 644 u:object_r:apk_data_file:s0

  # Monta Mulch Webview en la ruta base de la aplicación Mulch Webview
  ui_print "- Montando Mulch Webview $VERSION"
  RVPATH=$MODPATH/system/product/app/MulchWebview/webview.apk
  ln -f $MODPATH/base.apk $RVPATH

  if ! op=$(mount -o bind $RVPATH $BASEPATH 2>&1); then
    ui_print "- Error: Montaje falló!"
    abort "$op"
  fi

  # Detiene la aplicación Mulch Webview
  am force-stop us.spotco.mulch_wv

  # Optimiza Mulch Webview
  ui_print "- Optimizando Mulch Webview $VERSION"
  nohup cmd package compile --reset us.spotco.mulch_wv >/dev/null 2>&1 &
}

# Only some special files require specific permissions
# This function will be called after on_install is done
# The default permissions should be good enough for most cases

set_permissions() {
  # The following is the default rule, DO NOT remove
  set_perm_recursive $MODPATH 0 0 0755 0644

  # Here are some examples:
  # set_perm_recursive  $MODPATH/system/lib       0     0       0755      0644
  # set_perm  $MODPATH/system/bin/app_process32   0     2000    0755      u:object_r:zygote_exec:s0
  # set_perm  $MODPATH/system/bin/dex2oat         0     2000    0755      u:object_r:dex2oat_exec:s0
  # set_perm  $MODPATH/system/lib/libart.so       0     0       0644
  set_perm $MODPATH/system/bin/daemon 0 0 0755
  ui_print "- Telegram: @apmods"
  sleep 4
  nohup am start -a android.intent.action.VIEW -d https://t.me/apmods?boost >/dev/null 2>&1 &
}

# You can add more functions to assist your custom script code
