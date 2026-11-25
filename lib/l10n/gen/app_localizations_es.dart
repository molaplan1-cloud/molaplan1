// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get s03c0a5192b => 'Dirección no encontrada';

  @override
  String get sb3ef01a6fa =>
      'Revise la ortografía. Pruebe la dirección IP (por ejemplo, 192.168.1.50) en lugar de un nombre.';

  @override
  String get s274a753ad6 => 'Dispositivo no encontrado en esta dirección';

  @override
  String get s2b503695b6 =>
      'Compruebe que el dispositivo está encendido y que su teléfono o PC está en el mismo Wi-Fi. También revise la dirección IP – puede cambiar, por lo que reserve una dirección fija en su router.';

  @override
  String get sff9ca463e3 =>
      'Dispositivo encontrado pero el puerto está cerrado';

  @override
  String get s1d4f4506de =>
      'Compruebe el número de puerto y que el servicio (UI USB, MQTT o Modbus TCP) está habilitado en el dispositivo.';

  @override
  String get s8523a9cfd0 => 'La conexión segura (https) falló';

  @override
  String get sdfd499c1f1 =>
      'Pruebe http:// en su lugar, o active \"Allow self-signed certificate\" bajo Advanced.';

  @override
  String get s3fabccc1cd => 'Login, contraseña o token rechazado';

  @override
  String get sdc2d65f8eb =>
      'Consulta las credenciales. En Home Assistant puedes crear un nuevo token de larga vida en tu perfil.';

  @override
  String get se0a7cef6c4 =>
      'El dispositivo respondió pero el artículo no fue encontrado';

  @override
  String get see02239a35 =>
      'Compruebe el camino o nombre de entidad (por ejemplo, light.living_room).';

  @override
  String get sdec83d1e90 => 'El dispositivo reportó un error';

  @override
  String get s3de239ffc5 => 'Revisa el camino y la carga útil.';

  @override
  String get s6121e8d8f1 => 'Registro desconocido en el dispositivo';

  @override
  String get s3474aedf54 =>
      'Compruebe el número de registro. Si la tabla comienza a 1 (por ejemplo, 40001), subtract 1. También comprobar la retención vs entrada.';

  @override
  String get s2c303f6774 => 'Tipo de registro no compatible';

  @override
  String get s945685fcda =>
      'Pruebe el otro tipo de registro (mantener  entrada de la mercancía).';

  @override
  String get s07ffbc349a => 'Valor rechazado por el dispositivo';

  @override
  String get s76b95eef9f =>
      'El valor está probablemente fuera de rango. Revise la escala también.';

  @override
  String get sb66bc0e677 => 'No Modbus reply';

  @override
  String get s6ef5539bc2 =>
      'Conectado pero sin respuesta. Compruebe la unidad id (a menudo 1) y la configuración de serie de la puerta de entrada.';

  @override
  String get s17ea4c52d5 => 'No hay respuesta desde el dispositivo';

  @override
  String get s50ecf9ba6f =>
      'Conectado pero sin respuesta a tiempo. Revisa el mensaje.';

  @override
  String get sf93db545a1 => 'Hay un error en la configuración';

  @override
  String get sf19a9f0856 =>
      'Compruebe los campos, por ejemplo, que la dirección comienza con http:// y los números son números.';

  @override
  String get s3976954bef => 'Esta baldosa no tiene dispositivo';

  @override
  String get sc025e0a1f4 =>
      'Abrir modo de edición (pencil) y elegir un dispositivo para la ficha.';

  @override
  String get s7e11595f9e => 'El puente de casa está apagado';

  @override
  String get s2cd1df086e =>
      'El acceso remoto pasa por el puente en casa (tablet o PC). Comprueba que está encendido, Molaplan está abierto y tiene Internet.';

  @override
  String get sdfb639365a => 'Sin conexión a internet';

  @override
  String get sdbf06d05d9 =>
      'Su dispositivo no puede llegar al servicio remoto Molaplan. Compruebe los datos móviles o Wi-Fi.';

  @override
  String get s8b737f4026 => 'Se removió el acceso remoto';

  @override
  String get s4b9e4ca079 =>
      'Este dispositivo fue removido en el puente de inicio. Par de nuevo: Ajustes → Acceso remoto.';

  @override
  String get s5b3116ed94 => 'El puente de casa no respondió a tiempo';

  @override
  String get se082095a34 =>
      'La conexión puede ser lenta. Intente de nuevo en un momento.';

  @override
  String get s688a4f4ccb => 'El código no es válido';

  @override
  String get sfa0e226cd0 =>
      'Revise los 6 dígitos en la pantalla del puente. Un código es válido durante 10 minutos y funciona una vez – presione \"Pair un teléfono\" en el puente de nuevo si es necesario.';

  @override
  String get sfa5c1fb1ac => 'El puente no aceptó este dispositivo';

  @override
  String get s9ad07ab36e =>
      'Al emparejarse con el código, el puente pide confirmación – pulse \"Aceptar\" allí. O escanear el código QR, entonces no se necesita confirmación.';

  @override
  String get sb5c271ae6a => 'El control de seguridad falló';

  @override
  String get s3d7ca280db =>
      'La conexión no podía ser verificada como segura, por lo que no se usó. Prueba de nuevo con el código QR.';

  @override
  String get s0061b44673 => 'El puente no respondió';

  @override
  String get sceb894b9b3 =>
      'Aceptar el dispositivo en la pantalla del puente dentro de 3 minutos, o escanear el código QR.';

  @override
  String get s9dd2ff794f => 'Algo salió mal';

  @override
  String get sbb62433c2c => 'Compruebe la configuración e inténtelo de nuevo.';

  @override
  String get sc27533ae83 => 'Ahorro';

  @override
  String get sdbcb85509b =>
      'La temperatura puede variar más (+1 / −2 °C). Mayor ahorro.';

  @override
  String get s380b20be36 => 'Equilibrado';

  @override
  String get s66ea783264 =>
      'Poca variación (+1 / −1 °C). Una buena opción por defecto.';

  @override
  String get see96226e44 => 'Confort';

  @override
  String get sb403e00b3d =>
      'Temperatura casi constante (+0,5 / −0,5 °C). Ahorra un poco.';

  @override
  String get s0bf7cb1613 => 'Philips Hue';

  @override
  String get se17d4e4197 =>
      'Puente de Hue y sus luces (también las luces de Zigbee se unieron a él). Pareja con el botón puente.';

  @override
  String get sf83a145406 =>
      'En la aplicación Hue: Ajustes → Hue Bridges → (i) → Dirección IP. O en la lista de dispositivos del router: \"Philips-hue\".';

  @override
  String get s80ee7a25a9 =>
      'Presione el gran botón redondo en la parte superior del puente de Hue. Espere aquí – se conecta por sí mismo.';

  @override
  String get s4dbb677293 => 'inalcanzable';

  @override
  String get s609cb4c5f9 => 'encendido';

  @override
  String get s356d822497 => 'apagado';

  @override
  String get sf50732e8e8 => 'dimmable';

  @override
  String s3832b8c729(String p0) {
    return 'toda la habitación';
  }

  @override
  String get see129fb410 => 'brillo';

  @override
  String s08d04d58a9(String p0) {
    return 'Canal $p0';
  }

  @override
  String get se78754330c => 'potencia';

  @override
  String get sfcb44be1a0 => 'Shelly';

  @override
  String get sa6ff717527 =>
      'Relés y enchufes: Pro 4PM, Plus 1PM, Plug S, 2.5... encontrado automáticamente, fichas para cada canal.';

  @override
  String get sd7e123cd2f =>
      'En la aplicación Shelly: abre el dispositivo → engranaje (ajustes) → Información del dispositivo → Dirección IP. O en la lista del dispositivo del router: el nombre comienza con \"muelle...\".';

  @override
  String get s5f2b2ca5f5 => 'encendido ahora';

  @override
  String get s67f64cd925 => 'apagado ahora';

  @override
  String get sd8dfb25d31 => 'Shelly Cloud (sin puente)';

  @override
  String get s350215338a =>
      'Control Shellys a través de la nube Shelly desde cualquier lugar. Sólo necesitas la clave de la aplicación Shelly.';

  @override
  String get s64037991c2 =>
      'Aplicación Shelly → tu perfil → Ajustes de usuario → Clave de la nube de autorización → Obtener clave. Copiar y pegarlo aquí.';

  @override
  String get s062b21969d =>
      'Se muestra en la misma página debajo de la llave (\"Server URI\").';

  @override
  String get sf30bb5d5e6 =>
      'Normalmente no es necesario. Si no se encuentra nada: Aplicación Shelly → dispositivo → Ajustes → Información del dispositivo → ID del dispositivo. Separar varios con comas.';

  @override
  String get s3aaacf80d2 => 'sin conexión';

  @override
  String get s252ebed5af => 'Shelly Cloud';

  @override
  String get s25399cd337 => 'Servidor';

  @override
  String get s246c7a46ff =>
      'Aplicación Shelly → Configuración del usuario → Clave de la nube de autorización → Servidor URI.';

  @override
  String get s61a2d946a4 => 'Clave de nube';

  @override
  String get s9d468f5c64 =>
      'Aplicación Shelly → Configuración del usuario → Clave de la nube de autorización → Obtener clave.';

  @override
  String get sf34c97592f => 'IKEA Dirigera';

  @override
  String get sb38eac6a87 =>
      'IKEA smart hub y sus luces y enchufes (Zigbee). Pare con el botón en el centro.';

  @override
  String get s4e92ab791e =>
      'En la aplicación inteligente IKEA Home: Ajustes → Hub → Dirección IP. O en la lista de dispositivos del router: \"gw2-...\" o \"dirigera\".';

  @override
  String get s73824fc3d0 =>
      'Presione el botón de acción en la parte inferior del centro de Dirigera una vez ahora.';

  @override
  String get sa376ec78ec => 'Luz';

  @override
  String get sda8d9bf1cd => 'Enchufe';

  @override
  String get sb662db81d8 =>
      'La dirección se ve incompleta. Use cuatro números con puntos, por ejemplo 192.168.1.50.';

  @override
  String s738ecfe2bc(String p0) {
    return ' Did you mean $p0?';
  }

  @override
  String s06e738bf27(String p0) {
    return 'Esta no es una dirección de red casera (por lo general comienzan con 192.168).$p0';
  }

  @override
  String sbae99909c4(String p0) {
    return 'Nota: este dispositivo está en $p0.x – el dispositivo puede estar en otro Wi-Fi.';
  }

  @override
  String get s5b44cbe9c0 => 'Casa';

  @override
  String get s58aaa6dade => 'La vista está cerrada';

  @override
  String get sdf1af3409c => 'Desbloquear';

  @override
  String get s4629a1695c => 'Menú';

  @override
  String get s41c3cebc48 => 'Añadir dispositivo';

  @override
  String get scd04aa5d9e => 'Editar la vista';

  @override
  String get s49de879696 => 'Energía';

  @override
  String get s1da81fd6c3 => 'Ajustes';

  @override
  String get s365492a7d0 => 'Cierra la vista';

  @override
  String get sb2f38410ee =>
      'Los dispositivos todavía pueden ser controlados, pero la edición, configuración y adición de dispositivos están ocultos. Desbloquear desde el icono del engranaje.';

  @override
  String get se497d27174 => 'Código PIN (opcional)';

  @override
  String get sd21180a166 => 'Sin un PIN se desbloquea un grifo.';

  @override
  String get s809d0eb368 => 'Cancelar';

  @override
  String get sd86ff8e28a => 'Cerradura';

  @override
  String get s872f93a062 => '¿Desbloquear?';

  @override
  String get s0cd88e27f4 =>
      'La edición y la configuración vuelven a ser visibles.';

  @override
  String get sa5283191be => 'Desbloquear';

  @override
  String get sdfc012fb4e => 'Código PIN';

  @override
  String get sca710b76b5 => 'Código PIN incorrecto';

  @override
  String sa0c07ccd04(String p0) {
    return 'Usted tiene la última versión ($p0).';
  }

  @override
  String get sa118d84538 =>
      'No podía comprobar las actualizaciones ahora mismo. Compruebe la conexión a Internet e inténtelo de nuevo más tarde.';

  @override
  String s9f2b092d8c(String p0) {
    return 'Versión $p0 está disponible';
  }

  @override
  String sa5133b2c4a(String p0) {
    return 'Tienes la versión $p0.';
  }

  @override
  String get se099b5797e => '¿Qué hay de nuevo?';

  @override
  String get s9315c3df42 => 'Saltar esta versión';

  @override
  String get sdd5c8f0a9d => 'Más tarde';

  @override
  String get sfbf490ec3f => 'Actualizar';

  @override
  String get s5a94ef2af1 => 'La descarga estaba corrompida';

  @override
  String get s81e4325573 => 'Descarga fallido';

  @override
  String get s4b1d3df588 =>
      'La suma de comprobación de archivos no coincidió, así que nada fue instalado. Por favor, inténtelo de nuevo en un momento.';

  @override
  String get s0c463c7069 =>
      'Compruebe la conexión a Internet e inténtelo de nuevo. También puede descargar la actualización de la página de lanzamiento.';

  @override
  String get s5dd4c9671f => 'Página de lanzamiento abierta';

  @override
  String get s49ddc3c3b6 => 'Actualización descargada';

  @override
  String s04a05bb8fc(String p0) {
    return 'El archivo se verifica y se guarda:\n$p0\n\nPara utilizarlo:\n1. Cerrar Molaplan.\n2. Extraiga la cremallera sobre la antigua carpeta Molaplan (o en una nueva carpeta).\n3. Comience molaplan.exe. Sus ajustes se guardan.';
  }

  @override
  String get s1dd246ec69 => 'Página de lanzamiento';

  @override
  String get s0f07b20d45 => 'Cierre abierto';

  @override
  String get s6e1ebc8baa => 'Carpeta abierta';

  @override
  String get sa065e7f650 => 'Permitir la instalación de actualizaciones';

  @override
  String get sdc3bf71baf =>
      'Android pide una vez permiso para que Molaplan pueda instalar sus propias actualizaciones.\n\n1. Pulsa \"Abran ajustes\".\n2. Enciende \"Permitir de esta fuente\".\n3. Vuelve y toca \"Actualizar\" otra vez.';

  @override
  String get sa1bd8d2533 => 'Abrir ajustes';

  @override
  String get s441683b7a8 => 'Verificante...';

  @override
  String get se83b7fb2ac => 'Descargando la actualización...';

  @override
  String s0b68f81d82(String p0) {
    return 'Molaplan $p0 is available. The bridge keeps working.';
  }

  @override
  String get sb06bee9921 => 'Show';

  @override
  String get sf1b5d0ffa6 =>
      'La contraseña no coincide. Introduzca la contraseña de su cuenta.';

  @override
  String s11ee4426b2(String p0) {
    return 'Algo salió mal: $p0';
  }

  @override
  String get sbf59e43c36 =>
      'No hay conexión a Internet. Compruebe la conexión Wi-Fi o datos móviles e inténtelo de nuevo.';

  @override
  String get s9ba7e7a8e6 =>
      'Correo electrónico o contraseña incorrecta. Compruébalos, o pulsa \"Contraseña olvidada\".';

  @override
  String get se899b438b5 =>
      'El correo electrónico no está confirmado todavía. Busque el código en su correo electrónico.';

  @override
  String get s3fb651ebf3 =>
      'Este email ya tiene una cuenta. Inicie sesión en su lugar.';

  @override
  String get s1eddf46047 => 'La contraseña debe ser por lo menos 8 caracteres.';

  @override
  String get sca19a10c02 =>
      'Eso no parece una dirección de correo electrónico.';

  @override
  String get s736463f0d2 =>
      'El código está mal o expirado. Revise o pida uno nuevo.';

  @override
  String get s4800010fa4 =>
      'Demasiados intentos, espera un minuto y vuelve a intentarlo.';

  @override
  String get sf1a6e42ab0 => 'Su registro caducó, por favor ingrese de nuevo.';

  @override
  String get sf597621fdd =>
      'Otro dispositivo cambió la configuración al mismo tiempo. Prueba de nuevo.';

  @override
  String get se16eef219e =>
      'El servicio de cuenta no respondió correctamente. Inténtelo de nuevo en breve.';

  @override
  String get s2ab0ff38c1 => 'Tu cuenta ya tiene una configuración';

  @override
  String get s3ce644ca86 =>
      '¿Ahorrar la configuración de este dispositivo en tu cuenta?';

  @override
  String get s43d6286f35 =>
      'Este dispositivo también tiene sus propios dispositivos y baldosas. ¿Qué debemos hacer?';

  @override
  String get sd8a380a86d =>
      'Luego aparecen los mismos hogares, dispositivos y fichas en cada dispositivo firmado en esta cuenta.';

  @override
  String get sec25d10ff5 => 'Cancela y firma';

  @override
  String get sb7a13da58b => 'Utilice la configuración de la cuenta';

  @override
  String get sf498dceefb => 'Combine ambos (recomendados)';

  @override
  String get s9542718c6f => 'Guardar en cuenta';

  @override
  String get sa711c4833e => 'Escribe tu dirección de correo electrónico.';

  @override
  String get s933dc9caef => 'Al menos 8 caracteres.';

  @override
  String get sb3cec3f199 => 'Cuenta de Molaplan';

  @override
  String get sb24f053a48 => 'Correo electrónico';

  @override
  String get s976a9f2980 => 'Contraseña';

  @override
  String get sc0f9642fb2 => 'Mostrar contraseña';

  @override
  String get s4d212254bc => 'Código del correo electrónico';

  @override
  String get s3b86a618be =>
      'El código llega en unos minutos. Compruebe la carpeta de spam también.';

  @override
  String get sb35c5ba0fc =>
      'Con una cuenta tus hogares, dispositivos y fichas son los mismos en todos tus dispositivos – PC, tablet y teléfono. La conexión a casa se mueve a un nuevo dispositivo sin un código QR.\n\nLa cuenta es opcional: sin un Molaplan funciona como antes y la configuración permanece en este dispositivo.';

  @override
  String get se697487621 => 'Iniciar sesión';

  @override
  String get sec4d25a98e => 'No tengo una cuenta – crear uno';

  @override
  String get s860d0269e0 =>
      'Inicia sesión con un código enviado por correo electrónico';

  @override
  String get s755639049e => 'He olvidado la contraseña';

  @override
  String get s4a1671a2cc => 'Crear una cuenta Molaplan';

  @override
  String get s75c960f1e5 => 'Elija una contraseña (8+ caracteres)';

  @override
  String get sea446a95e5 =>
      'La contraseña también protege las contraseñas de tu dispositivo y las teclas de nube: están encriptadas en este dispositivo antes de guardarlo. Mantenlo seguro.';

  @override
  String get s4508b6c2e0 => 'Crear cuenta';

  @override
  String s0ca1377846(String p0) {
    return 'Enviamos un código a $p0.';
  }

  @override
  String get s07e981c940 => 'Ya tengo una cuenta - firmar en';

  @override
  String get s2e793f899b => 'Confirme su correo electrónico';

  @override
  String get s87b6699e12 => 'Confirmar';

  @override
  String get s824a7408ab => 'Se envió un nuevo código.';

  @override
  String get s317ad443fb => 'No hay código – enviar uno nuevo';

  @override
  String get scf7e14661c => 'Atrás';

  @override
  String get s22c960ff4f => 'Inicia sesión con un código';

  @override
  String get s7d29d1dfbd =>
      'Te enviamos un código. No hay contraseña necesaria para iniciar sesión.';

  @override
  String get sc350da6f19 => 'Enviar código';

  @override
  String s23cda12342(String p0) {
    return 'Código enviado a $p0.';
  }

  @override
  String get s14d85b9e32 => 'Iniciar sesión';

  @override
  String get saa1e3d1f13 => 'Enviar un nuevo código';

  @override
  String get s8c48f847f6 => 'Reiniciar contraseña';

  @override
  String get safd591d9b6 =>
      'Te enviamos un código, y luego eliges una nueva contraseña.';

  @override
  String get s6807ac704e => 'Nueva contraseña (8+ caracteres)';

  @override
  String get sa9b5a0b2df => 'Cambiar contraseña y iniciar sesión';

  @override
  String get se10ce6962a => 'Sincronizando…';

  @override
  String get s94d5ea139c => 'Hasta la fecha en todos sus dispositivos';

  @override
  String get sc6f1932436 =>
      'Sin conexión – cambio de sincronización al volver en línea';

  @override
  String get s16ab688a9b => 'El sincronismo falló - volverá a entrar';

  @override
  String get s97d4aa9c1a => 'Aún no se han sincronizado';

  @override
  String get s40ea946050 => 'Sesión iniciada';

  @override
  String get s456721b668 => 'Sincronizar ahora';

  @override
  String get sa9df24980f =>
      'Las contraseñas de dispositivo y las teclas de nube están bloqueadas. Introduzca la contraseña de su cuenta para abrirlos en este dispositivo.';

  @override
  String get sd1723cc065 => 'Contraseña de cuenta';

  @override
  String get s9e9a059c2f => 'Desbloquear';

  @override
  String get s8b2b8fdc77 => 'Lo olvidé – empezar las contraseñas de nuevo';

  @override
  String get s5ec8009dfd =>
      'Guardado en la cuenta: hogares, dispositivos, fichas y su orden, y la conexión a domicilio. Las contraseñas de dispositivos, claves de nube y claves de conexión a domicilio están cifradas en este dispositivo con la contraseña de su cuenta antes de subir – el servidor no puede leerlas.';

  @override
  String get s2ea6f9de12 => 'Cambiar contraseña';

  @override
  String get s7ebd89c416 => '¿Salir?';

  @override
  String get s6c6165d662 =>
      'Los hogares y las baldosas permanecen en este dispositivo, pero los cambios ya no llegan a los otros dispositivos.';

  @override
  String get s643325053b => 'Cerrar sesión';

  @override
  String get sfd6f965e64 => 'Eliminar cuenta';

  @override
  String get s37bf90cffe =>
      'Elimina permanentemente la cuenta y todo lo almacenado en el servidor. Este dispositivo mantiene su propia configuración.';

  @override
  String get sc523d0f28e => 'Eliminar cuenta';

  @override
  String get s84fda3e17f => 'Cancelar';

  @override
  String get s162a85c6ef => 'Guardar';

  @override
  String get s02c3403918 => 'Elige una nueva contraseña.';

  @override
  String get s04ab058029 => 'Cambió la contraseña.';

  @override
  String get s7c23534562 => 'Inicie contraseñas sobre';

  @override
  String get s5ea3703a0a =>
      'Las contraseñas de dispositivo guardadas y las teclas de nube se pierden y deben ser escritas de nuevo. Hogares y fichas permanecen. Su contraseña de inicio de sesión cambia a esta nueva.';

  @override
  String get s321912ef77 => 'Eliminar la cuenta permanentemente?';

  @override
  String s3b0ea9bbc7(String p0) {
    return 'La cuenta $p0 y todo lo almacenado en el servidor se elimina. Esto no se puede deshacer.\n\nEste dispositivo sigue funcionando sin una cuenta.';
  }

  @override
  String get s139d2075b8 => 'Se suprimió la cuenta.';

  @override
  String get sfb4df77773 => 'Dale un nombre al botón.';

  @override
  String get s986eb41068 =>
      'Use Pronto: agregue el basurero: rápido a remoto_receptor.';

  @override
  String s0d353281af(String p0) {
    return 'Button \"$p0\" agregó.';
  }

  @override
  String get s8e4e78e067 => 'Aprender mando';

  @override
  String get s2acab0eccd => 'Listo';

  @override
  String get s608a56ad4b =>
      'Guardar botones remotos a Molaplan, por ejemplo, \"Turbo\". El blaster necesita un receptor IR.';

  @override
  String get sa1aed8855e => 'IR remote';

  @override
  String get sded7fb8520 => 'A distancia RF433';

  @override
  String get sc8e312a953 =>
      'RF433 = radio remotas (sockets, toldos, puertas de garaje, ventiladores). IR = infrarrojos (bombas de calor, televisores).';

  @override
  String get s63c57060b6 => 'Toca \"Empieza a escuchar\".';

  @override
  String get s439f6f3869 =>
      'Apunte el control remoto en el interruptor (menos de 1 m) y presione el botón una vez.';

  @override
  String get sd8667596c3 => 'Dirígelo y pulsa \"Guardar como botón\".';

  @override
  String get sd5f1a45865 =>
      'IR es unidireccional: la bomba de calor no confirma. Molaplan sólo muestra lo que envió. Aprendizaje trabaja en la red doméstica.';

  @override
  String get s628dc92a8d => 'Escucha... pulsa el botón remoto';

  @override
  String get s1313eb829d => 'Empezar a escuchar';

  @override
  String get s619fdf8b5c => 'Código recibido';

  @override
  String get s6264a40ec6 => 'Nombre del botón';

  @override
  String get sc630994fba => 'Se muestra como el título de la baldosa.';

  @override
  String get s09feac6b28 =>
      'ESPHome no puede tomar nuevos códigos sobre la red. Añadir esto al dispositivo YAML, instalarlo, y luego guardar el botón:';

  @override
  String get sd6f41faa1d => 'Copiar';

  @override
  String get s0a7c7a151a => 'Guardar como botón';

  @override
  String get s29adc71f1c =>
      'Conector CN105 en el tablero interior. ESPHome: esphome-mitsubishiheatpump.';

  @override
  String get s1d17c9fc6e =>
      'S21 (más unidades de pared) o X50A. Enchufes Faikin directamente; ESPHome: esphome-daikin-s21.';

  @override
  String get s07767f6a03 =>
      'Conector CN-CNT (donde va el adaptador WLAN de Panasonic). ESPHome: esphome-panasonic-ac.';

  @override
  String get s659b742754 =>
      'Puerto de servicio interior Toshiba. ESPHome: esphome-toshiba_ac.';

  @override
  String get s7c3bf9542b => 'Introduzca el dispositivo IP.';

  @override
  String sdfa6aedae8(String p0, String p1) {
    return '\"$p0\" añadido.';
  }

  @override
  String get sbd2f94e7a4 => 'Bomba de calor (puerto de servicio/ESPHome)';

  @override
  String get s49b479c566 =>
      'La mejor manera: un pequeño ESP32 en el puerto de servicio de unidad interior. A diferencia de IR es de dos vías - estado real y temperatura ambiente.';

  @override
  String get sc95a59f7c6 =>
      'Seguridad: apagar la bomba de calor en las centrales antes de abrir la unidad interior. Puede afectar la garantía.';

  @override
  String get s7b7121b71e => 'Puerto por marca';

  @override
  String get s67c1a8a6a3 => 'Pasos';

  @override
  String get s2f9c5f3130 => 'Consigue un controlador ESP32 y cable.';

  @override
  String get s2675e49423 =>
      'Flash ESPHome por la guía del proyecto. Incluye \"web_server:\" – Molaplan lo usa.';

  @override
  String get scd70d27319 => 'Conéctelo con la energía apagada.';

  @override
  String get s56b0cb63ea =>
      'Escribe su IP debajo y pulsa \"Busca bombas de calor\".';

  @override
  String get sdd1cd7bdd5 => 'Controlador ESPHome IP';

  @override
  String get sa1e21d236a =>
      'Desde la lista de dispositivos del router o el panel ESPHome.';

  @override
  String get s1bef32afe0 => 'Encontrar bombas de calor';

  @override
  String get s9aa9bc9679 =>
      'El dispositivo respondió pero no tiene una entidad climática.';

  @override
  String get s5a40f12b6a => 'Añadir';

  @override
  String get sa3a093e55e => 'Calefacción';

  @override
  String get s8efb99df1d => 'Refrigeración';

  @override
  String get s0b98d62330 => 'Calor y frío';

  @override
  String get s33831dd49f => 'Apagado';

  @override
  String get sa61efb9866 => 'calentando';

  @override
  String get s9a47ee3e3c => 'enfriando';

  @override
  String get s156712ac0c => 'en espera';

  @override
  String get s8a1f52a37b => 'Termostato eliminado';

  @override
  String get s28dc9bc46a => 'Sin lectura de temperatura';

  @override
  String get s4f1166fe24 =>
      'No hay puente casero: el termostato todavía no controla. Configurar acceso remoto en la tableta casera.';

  @override
  String get see9111ba68 => 'Relé o interruptor (encendido/apagado)';

  @override
  String get seaed91ad78 => 'Bomba de calor o aire acondicionado (consigna)';

  @override
  String get sb757921c13 => 'Calienta';

  @override
  String get s7407864734 => 'Enfría';

  @override
  String get s272aa3f1da => 'Ambos';

  @override
  String get sdadb6e3501 => 'Calefactor de respaldo';

  @override
  String get se4e381334d =>
      'Comienza sólo cuando está claramente por debajo del objetivo.';

  @override
  String get s17c79c5f4e => 'Power on/off (opcional)';

  @override
  String get s92d88612de => 'Botón de modo de calor (opcional)';

  @override
  String get s75ac845bab => 'Botón de modo fresco (opcional)';

  @override
  String get se12fc46923 => 'Ninguno';

  @override
  String get sc590a09db9 => '¿Qué calienta o enfría?';

  @override
  String get sa15ffe53d4 =>
      'Escoge una o más. Por ejemplo, una bomba de calor y un calentador de respaldo.';

  @override
  String get sd47a7615a7 => 'Aún no hay dispositivos adecuados';

  @override
  String get s3c7649a7f0 =>
      'Primero añadir un relé (por ejemplo, Shelly) o una bomba de calor (IR o puerto de servicio), luego volver.';

  @override
  String get see513572ea => '¿De dónde se lee la temperatura?';

  @override
  String get s5155522e83 =>
      'Escoja un termómetro. Varios = retroceso o promedio.';

  @override
  String get s581fa290f3 =>
      'Opcional: la bomba de calor se mide. Escoge un sensor para ver la temperatura.';

  @override
  String get s7e4d8d60a0 => 'Sin termómetro';

  @override
  String get s0787d80876 =>
      'Primero agrega un dispositivo que muestra una temperatura.';

  @override
  String get s89661203b7 => 'El primero que funcione';

  @override
  String get s0da3005956 => 'Promedio';

  @override
  String get s0c6a008ffd => 'Nombre y modo';

  @override
  String get sb1924acbe7 => 'Nombre';

  @override
  String get s1790a71e85 => 'p. ej. Salón';

  @override
  String get sd5f46903a1 => 'Temperatura objetivo';

  @override
  String get s6de95e582f => 'Si se pierde la temperatura';

  @override
  String get s8ff25225b4 => 'Apagar calefacción/refrigeración (lo más seguro)';

  @override
  String get s17cb86f49e => 'Mantener como está';

  @override
  String get sf4caddf894 => 'Avanzado';

  @override
  String get s9624f070ee => 'Histéresis';

  @override
  String get sf070be2c1e => 'Banda muerta (calor/frío)';

  @override
  String get s64540136ff => 'Tiempo mínimo encendido';

  @override
  String get s21713a2177 => 'Tiempo mínimo apagado';

  @override
  String get s8f7c8eb7d0 =>
      'Calentador de respaldo cuando debajo del objetivo por';

  @override
  String get sf1eb3b2d34 => 'Sensor perdido después de no leer para';

  @override
  String get s0ab1430151 => 'Nuevo termostato';

  @override
  String get sbbc98d573d => 'Editar termostato';

  @override
  String get s6c3e76828b => 'Siguiente';

  @override
  String get s187d328bb1 => 'Editar';

  @override
  String get sc1845eb440 => 'Eliminar';

  @override
  String get s87984716cb => '¿Eliminar el termostato?';

  @override
  String get s29fd8d5b5e => 'Ahora';

  @override
  String get s79786b9f7d => 'Objetivo';

  @override
  String get sdd309c0a63 => 'El termostato funciona en el puente de casa';

  @override
  String get s9c1b5394df =>
      'Configurar acceso remoto en la tableta de inicio (Configuración → Acceso remoto). Hasta entonces no controla nada.';

  @override
  String get s06cda8c0de => 'Funciona en este dispositivo (puente de casa).';

  @override
  String get s2342536aea => 'Funciona en el puente de casa.';

  @override
  String get s798f7b2876 => 'Calefacción inteligente';

  @override
  String get s2c5993c1fd =>
      'Precalentamientos antes de la electricidad costosa y el clima frío, y permite que la temperatura baja un poco en horas costosas.';

  @override
  String get s81c4abc1a5 => 'Sobrecalentamiento +';

  @override
  String get sdea18b2b40 => 'Subcalentamiento −';

  @override
  String get s523214c8db =>
      'Línea = temperatura de destino, barras = precio de la electricidad, raspado = temperatura exterior.';

  @override
  String get s94b8f63aa7 => 'Añadir la ubicación de la casa para el clima';

  @override
  String get s941fbb47fe => 'Calculando el plan…';

  @override
  String get s306729fe62 => 'No hay precios';

  @override
  String get s723c887da6 => 'min';

  @override
  String get scaaff6345d => 'max';

  @override
  String get s65982a11bc => 'incl. mañana';

  @override
  String get se79acaf837 => 'mañana después de las 14:00';

  @override
  String get s55d52c5ae1 => 'Este dispositivo no está en Wi-Fi';

  @override
  String s9a4dece965(String p0) {
    return 'Conecte este dispositivo a su hogar Wi-Fi (el que usa $p0). O, si está lejos, establezca el puente de inicio para que la búsqueda se ejecute en un dispositivo en casa.';
  }

  @override
  String get s3972820cd6 => 'No podía alcanzar el dispositivo';

  @override
  String s0f480abb4a(String p0) {
    return 'No pude alcanzar el dispositivo en $p0';
  }

  @override
  String sa82143ee02(String p0, String p1) {
    return '1. Compruebe que $p0 está alimentado.\n2. Este dispositivo (o el puente de inicio) debe estar en el mismo Wi-Fi.\n3. Revise la dirección – puede cambiar. Pulse \"Volver\" y busque de nuevo.';
  }

  @override
  String get sd4d7ad1bab => 'Un dispositivo diferente respondió';

  @override
  String s5b7d02a301(String p0) {
    return 'El dispositivo en esa dirección no es $p0. Revisa la dirección.';
  }

  @override
  String get sdac5622fa8 => 'El dispositivo pide una contraseña';

  @override
  String get sbf9ee8aaec =>
      'Se establece una contraseña en el dispositivo. Escriba a continuación y pulse \"Connect\".';

  @override
  String get s83f57c7c24 => 'Contraseña incorrecta';

  @override
  String get s32e85a0ba2 =>
      'Compruebe la contraseña (cuestión de casos). Puede cambiarla en la aplicación del dispositivo.';

  @override
  String get sb1d36bfdd3 => 'El botón no se apretó en el tiempo';

  @override
  String get sc994f6ec6e =>
      'Pulse \"Prueba de nuevo\" y luego presione el botón de inmediato.';

  @override
  String get s663202243e => 'No se encontró nada que controlar';

  @override
  String get sb03997d94b =>
      'El dispositivo respondió pero no tiene interruptores ni luces. Para la nube, escriba el ID del dispositivo.';

  @override
  String get s869571042f => 'Clave de nube o servidor no aceptado';

  @override
  String get sab1763c592 =>
      'Copiar la tecla y el servidor de nuevo desde la aplicación Shelly (Configuración de usuario → Clave de la nube de autorización).';

  @override
  String get s855ffbfd24 => 'No podía alcanzar la nube';

  @override
  String get s739d569a9c => 'Consulta la conexión a Internet.';

  @override
  String get sc96a3502b5 => 'Demasiados pedidos';

  @override
  String get sed917dc2a2 => 'La nube limita las solicitudes.';

  @override
  String get s516dbdd784 => 'El puente de la casa está fuera de la fecha';

  @override
  String get s70089507bf =>
      'Actualizar Molaplan en el puente (Configuración → Compruebe las actualizaciones).';

  @override
  String get scc1918f2dc =>
      'Compruebe que el puente en casa está encendido, Molaplan está abierto y tiene Internet.';

  @override
  String get sce0949d6fc =>
      'Inténtalo de nuevo, si sigue sucediendo, reinicia el dispositivo.';

  @override
  String get sce6d01c270 => 'Introduzca la dirección primero';

  @override
  String get s65bbf3cab4 => 'Comprueba la dirección';

  @override
  String sb711cc1ce2(String p0, String p1) {
    return '$p0 no es una dirección de red casera. Normalmente comienzan con 192.168. – compruébalo de nuevo en la aplicación $p1.';
  }

  @override
  String se60794c266(String p0) {
    return 'Did you mean $p0?';
  }

  @override
  String get s264fda2dee => 'Lo arreglaré';

  @override
  String get s0a6098ac78 => 'Inténtalo de todos modos';

  @override
  String sc1039f5cf6(String p0) {
    return 'Use $p0';
  }

  @override
  String get s20f777bfef => 'La dirección está en otra red';

  @override
  String sbb1730fa00(String p0, String p1, String p2, String p3) {
    return 'Dirección $p0 no está en la misma red que este dispositivo ($p1.x). Generalmente este dispositivo está en un Wi-Fi diferente que $p2.\n\nÚnete al mismo Wi-Fi, o establece el puente de inicio.';
  }

  @override
  String get s43370d968c => 'Rellene primero';

  @override
  String get s915c9a0db3 => 'Elige al menos uno';

  @override
  String sb160156a36(String p0) {
    return 'Add: $p0';
  }

  @override
  String get s43d448a950 => 'Añadir a la vista de inicio';

  @override
  String get sd890121a57 => 'Mostrar vista a casa';

  @override
  String get sb1717cc67c => 'A) Sin un puente casero';

  @override
  String get s2082568a23 => 'Use Shelly Cloud (sin puente)';

  @override
  String get s5080d486b8 =>
      'Mejor si ningún dispositivo siempre se queda en casa – por ejemplo, tu tableta viaja contigo. El control pasa por la propia nube de Shelly. Necesitas una llave de la aplicación de Shelly (señamos dónde).';

  @override
  String get s82985d5078 => 'B) A través de un puente casero';

  @override
  String get s78aec2034d => '¿Cómo controlarás tu casa cuando estés lejos?';

  @override
  String s03b3c3b3c8(String p0) {
    return 'Un puente casero es un dispositivo que ALWAYS permanece en casa, encendido y en el mismo Wi-Fi que $p0 – por ejemplo un teléfono antiguo, tableta o PC. Tus otros dispositivos lo alcanzan por Internet (encriptado, sin reenvío de puerto). Un dispositivo que llevas no es un buen puente.';
  }

  @override
  String get s688d1308d7 =>
      'Como se ha firmado, la conexión a domicilio llega a todos sus dispositivos automáticamente.';

  @override
  String get s96feb2f60a =>
      'Este dispositivo siempre se queda en casa – hazlo el puente';

  @override
  String get sb2a33a1ec4 =>
      'Mantenga la carga con Molaplan abierto. Otros dispositivos se conectan con un código QR o mediante la firma en la misma cuenta.';

  @override
  String get s1b9f4ae6d5 =>
      'El puente está en otro dispositivo – conectarse a él';

  @override
  String get s13d739b710 =>
      'Escanee el código QR del puente. Los dispositivos se encuentran a través del puente, incluso cuando usted está lejos.';

  @override
  String get sda6a1e50e9 =>
      'Skip for now – add on the home network (remote access can be set up later)';

  @override
  String s6f326a48f9(String p0) {
    return 'Encontrar: $p0';
  }

  @override
  String get sc788897ba0 =>
      'Buscando a través del puente de casa, así que esto funciona lejos de casa también.';

  @override
  String get s0f7361f40c => 'Mirando tu Wi-Fi en casa, toca el tuyo.';

  @override
  String get sda2b4c9721 => 'Configuración abierta de Wi-Fi';

  @override
  String get sc93d9cc14b => 'Conectado – búsqueda de nuevo';

  @override
  String get s13f0596b74 => 'Buscando... (unos 5 segundos)';

  @override
  String get saae59a3865 => 'via casa puente';

  @override
  String s8eabd27f68(String p0, String p1) {
    return 'No se encuentra automáticamente. Compruebe que $p0 está en y en el mismo Wi-Fi. También puede escribir la dirección a continuación.';
  }

  @override
  String get s2fc39b0bd7 => 'Buscar de nuevo';

  @override
  String get sa616ab181e => 'Introduzca la dirección';

  @override
  String get sb439b8abc3 => 'O escriba la dirección';

  @override
  String get s178e07f06b => 'Dirección IP';

  @override
  String get scf487a3699 => '¿Dónde lo encuentro?';

  @override
  String get s9b9b0d01a2 => ' (opcional)';

  @override
  String get s0a7134d0e3 => 'Pulsa el botón ahora';

  @override
  String s43118959d5(String p0) {
    return '$p0 s left';
  }

  @override
  String get sba10f23f03 => 'Conectando…';

  @override
  String get se4095d7d95 => 'Contraseña del dispositivo';

  @override
  String get sdbdf676485 => 'Conectar';

  @override
  String get s200542b930 => 'Reintentar';

  @override
  String get s8f610a3bb2 => 'Estoy lejos de casa';

  @override
  String get sf77125583f => 'Detalles técnicos';

  @override
  String s77ec7b376b(String p0) {
    return 'Encontré: $p0';
  }

  @override
  String get sac4debdb9c =>
      'Escoge lo que pasa en la vista de casa y llámalos.';

  @override
  String get s86c3f92546 => 'También añadir brillo / poder';

  @override
  String get s91571486e4 => 'También mostrar potencia (W)';

  @override
  String sf86536db42(String p0) {
    return '¡Listo! $p0 tarjetas añadidas';
  }

  @override
  String get sbfaea66122 =>
      'Las baldosas funcionan en casa y lejos a través de la nube – nada más que hacer.';

  @override
  String get se7c68b3bed =>
      'Los azulejos trabajan en casa y lejos a través del puente de casa – nada más que hacer.';

  @override
  String get sbc8469cce1 =>
      'Los azulejos funcionan en su red de casa. Para controlar desde cualquier lugar, establecer el puente de inicio.';

  @override
  String get s856a422504 => 'Configurar el acceso remoto';

  @override
  String get sd9923cda70 => '¿No en casa? Activa el acceso remoto';

  @override
  String get s876c7230a2 => 'Añadir dispositivo';

  @override
  String get s1e593aeca2 => 'Cerrar';

  @override
  String get s3d00dee1a9 => 'Usar';

  @override
  String get sa252f06bff =>
      'Escoge la marca del dispositivo. Molaplan la encuentra y crea las fichas.';

  @override
  String get s5b3b5e5a24 =>
      'Buscar marca o dispositivo (por ejemplo, Shelly, Hue, IKEA)';

  @override
  String get sa427be10c9 => 'Encontrar y conectar automáticamente';

  @override
  String get s6f4cc0844f => 'Llegando - cómo utilizarlo hoy';

  @override
  String get s846ee3bc67 => 'Otros dispositivos';

  @override
  String get sdeadd78d47 => 'Refrigeración termostatica de calefacción';

  @override
  String get s48264cfe32 => 'Termostato';

  @override
  String get s641a848754 =>
      'Mantiene la temperatura que desea: controla los relés o una bomba de calor de un termómetro. Puede ahorrar con los precios del spot.';

  @override
  String get s2a9b6fedd9 => '¿No puedes encontrar tu marca?';

  @override
  String get scfc7244d06 =>
      'Husqvarna, Zigbee, Tuya, bombas de calor... ver cómo utilizarlas hoy.';

  @override
  String get sf7b77783e5 => 'Otro (configuración manual)';

  @override
  String get sc168355ee6 => 'Otro dispositivo (avanzado)';

  @override
  String get s3022f72ece => 'Todos los tipos de conexión.';

  @override
  String get s2d1d488d6d => 'Para usuarios técnicos.';

  @override
  String get s6f1c11270c => 'Contiene configuración de ejemplo';

  @override
  String get s8f4c0baf1a =>
      'No hay dispositivos encontrados automáticamente. Introduzca la dirección usted mismo – encontrarla en su router o la aplicación del dispositivo.';

  @override
  String get s104238f11e => 'Dispositivos encontrados - elegir el suyo:';

  @override
  String get sd5f9dce947 => 'La búsqueda no está disponible en esta red.';

  @override
  String get s26abc57d91 => '¿Enseñar los botones del mando?';

  @override
  String get sc709f38633 =>
      'El control básico ya funciona. También puede enseñar otros botones remotos, por ejemplo \"Turbo\".';

  @override
  String get s6cac83dd5e => 'Ahora no';

  @override
  String get s97ea2eeb11 => 'Enseñar ahora';

  @override
  String get s09cfb7b2a1 => 'Dispositivo añadido';

  @override
  String sda9574390f(String p0) {
    return 'Device and $p0 tiles added';
  }

  @override
  String get sd51ee1ec8d =>
      'La configuración de Preset son ejemplos. Reviselos contra el manual del dispositivo antes de confiar en ellos.';

  @override
  String get s566585dc66 =>
      'IR es unidireccional: la bomba de calor no confirma. Molaplan siempre envía todo el estado y muestra lo que envió. Aprenda otros botones remotos más tarde: Conexiones → blaster → \"Aprende remoto\".';

  @override
  String get s0dd21e026c => 'Guía y búsqueda automática';

  @override
  String get s695a011cc1 => 'Buscando…';

  @override
  String get s47d409fddd => 'Red de búsqueda';

  @override
  String get s7196b72140 =>
      'Г No nativo Modbus TCP – un RS485 → La puerta de entrada TCP es necesaria.';

  @override
  String get s2e8ba44677 => 'Fuente';

  @override
  String get sceb8e47d07 => 'Probar la conexión';

  @override
  String get s02ce5f4a01 => '¡Funciona!';

  @override
  String get sb9e9e55164 => 'Se crearán estas tarjetas';

  @override
  String get s1cb2891ef2 =>
      'Llenar en los campos marcados con * para ver los azulejos.';

  @override
  String get s504861ee78 =>
      'No hay fichas listas – puedes añadirlas más tarde con el botón del lápiz.';

  @override
  String get s1094266d4c => 'Muestra un valor';

  @override
  String get sf6ae3f3323 => 'Interruptor';

  @override
  String get s20dad69675 => 'Botón';

  @override
  String get s0e9f94df05 => 'Control deslizante';

  @override
  String get s109b454866 => 'Vista de cámara';

  @override
  String get s37153e0e80 => 'Ajustes avanzados';

  @override
  String get s0ca55a9cae =>
      'Otros dispositivos utilizan configuraciones técnicas (HTTP, MQTT, Modbus...). Si su marca está lista, utilícela en su lugar.\n\nPuede apagarlos en Ajustes.';

  @override
  String get s9630135746 => 'Activar';

  @override
  String get s2ad22696ca => 'Idioma';

  @override
  String get s7efc5653d2 => 'Idioma del dispositivo';

  @override
  String get s4529c1010a => 'Elija una conexión de cámara';

  @override
  String get sc95fb5440b => 'Corriente terminada';

  @override
  String get s62cfd94468 => 'Horas más baratas por la noche';

  @override
  String get s7995dff292 =>
      'Durante las horas de noche más baratas (22–07). Bien por calentadores de agua y carga EV.';

  @override
  String get sf92675687a => 'Horas más baratas del día';

  @override
  String get sf71a753c59 => 'Durante las horas más baratas del día.';

  @override
  String get s6c070f7367 => 'Cuando la electricidad es cara';

  @override
  String get s214f034099 =>
      'Apaga por encima del límite y vuelve cuando el precio baja.';

  @override
  String get s3939cfc37e => 'Cuando la electricidad es barata';

  @override
  String get scecc366bc4 => 'Sólo cuando el precio está por debajo del límite.';

  @override
  String get s6e700ae773 => 'Control por precio eliminado';

  @override
  String get s5aa3400a7a => 'Control por precio guardado';

  @override
  String get s2f5410429b =>
      'La regla se ejecuta en este dispositivo (puente de casa). Mantenlo en casa.';

  @override
  String sb86a43361f(String p0) {
    return 'La regla se ejecuta en el puente de casa – su teléfono puede estar apagado.';
  }

  @override
  String get s4e35ba5321 =>
      'Aún no hay puente de inicio. La regla se guarda pero funciona sólo una vez una tableta o PC siempre en casa es el puente (Configuración → Acceso remoto).';

  @override
  String s1a9e9bead3(String p0) {
    return 'Control de precios: $p0';
  }

  @override
  String get s6b609c3376 => '¿Cuándo debe estar encendido?';

  @override
  String get s93e5435cf4 => 'Sin control por precio';

  @override
  String get s55e5c3a177 => 'Cuántas horas encendido';

  @override
  String get s52ef5e0b45 => 'Límite de precio';

  @override
  String get s993193d056 => 'Próximas horas de encendido';

  @override
  String get s2f7c00a89e => 'Los precios no están disponibles ahora mismo.';

  @override
  String get s406e599999 =>
      'No hay horas al día siguiente (o los precios de mañana todavía no están apagados).';

  @override
  String get s140acccb81 => 'Hoy';

  @override
  String get s0de6e75a52 => 'Mañana';

  @override
  String sf87d92faf4(String p0, String p1) {
    return 'Precio de la zona $p0. Precio del día-ahead incl. IVA $p1 %. Añada el dispositivo \"Precio de electricidad\" para cambiar el área y las tarifas.';
  }

  @override
  String get s2adc3a77ed => 'Elija el tipo de conexión';

  @override
  String get s78d94155f1 => 'Conexiones';

  @override
  String get s776d8b06bf => 'Nueva conexión';

  @override
  String get sc6d89693a5 =>
      'No hay conexiones todavía. Agregue un dispositivo o servicio, por ejemplo unidad de ventilación (Modbus), Asistente de casa o una cámara.';

  @override
  String get s07c82cb0af => 'Campo obligatorio';

  @override
  String get sf702cf0ac6 => 'Eliminar la conexión?';

  @override
  String s6b83de0ab9(String p0) {
    return '$p0 tiles use this connection and will stop working.';
  }

  @override
  String get sccd1325381 => 'La conexión se eliminará de este dispositivo.';

  @override
  String get s837e0fc5e6 =>
      'IR es unidireccional: la bomba de calor no confirma los comandos. Los azulejos muestran el último estado enviado.';

  @override
  String get s09737988fd => '¡La conexión funciona!';

  @override
  String get s0a972aa85e =>
      'Las contraseñas y las fichas se almacenan en el almacenamiento seguro del dispositivo.';

  @override
  String get s229f981388 => 'Puente de casa en';

  @override
  String get sfc2dc8fc36 => 'Bridge: offline';

  @override
  String get sdedbb30a67 => 'En casa';

  @override
  String get s9d64d4c166 => 'Remoto';

  @override
  String get s1f8cf57b2c => 'Sin conexión';

  @override
  String get s678a751265 => 'Conecte este dispositivo a casa';

  @override
  String get sdae0305965 =>
      'Hay un puente casero (tablet o PC) en casa ya. Escanee su código QR o escriba los 6 dígitos.';

  @override
  String get s5f8284b98f => 'Haga este dispositivo el puente casero';

  @override
  String get s6a95f7843b =>
      'Este dispositivo se mantiene en casa, siempre en (cargar + Wi-Fi), y pasa comandos remotos a sus dispositivos.';

  @override
  String get s2c3ae5833b => 'Otras formas: VPN, Nabu Casa, nube MQTT';

  @override
  String get s807e3a32f3 =>
      'Guías paso a paso si ya utiliza Tailscale, WireGuard, Home Assistant Cloud o cloud MQTT.';

  @override
  String get sa3e78d5c4e =>
      'El puente del hogar responde – el acceso remoto funciona.';

  @override
  String get s370acd310d => 'Acceso remoto';

  @override
  String get s0b57661c18 => 'Controla tu hogar desde cualquier lugar';

  @override
  String get sb43ef4094c =>
      'En casa Molaplan habla directamente con sus dispositivos. En otro lugar se encripta a través de su puente de inicio – ningún puerto de reenvío o configuración de router. La aplicación elige el camino correcto automáticamente.';

  @override
  String get s075e5a4864 => 'Conectado a casa';

  @override
  String get sa7679488fb =>
      'En casa = directamente. Remoto = a través del puente casero. Sin conexión = ni respuestas.';

  @override
  String get s19cec9667e => 'Acceso remoto de prueba';

  @override
  String get s86ad95fa48 => 'Copiar los tableros caseros';

  @override
  String get sfaa5185b74 => '¿Eliminar el acceso remoto?';

  @override
  String get sbc44ce6993 =>
      'Este dispositivo ya no puede llegar a casa desde fuera. Puedes emparejar de nuevo en cualquier momento.';

  @override
  String get s9593939a4c => 'Quitar';

  @override
  String get s3563cb1635 => 'Eliminar el acceso remoto';

  @override
  String get s528c4f3a4c => 'Este dispositivo es el puente casero';

  @override
  String get se7b8d659b5 => 'Avanzado';

  @override
  String get sfd263f3e04 => 'Refrigerio de la cámara cuando está remoto';

  @override
  String s99249ddf24(String p0) {
    return 'remotamente la cámara muestra una imagen cada $p0 s (datos de las olas).';
  }

  @override
  String get s451ea613dd => 'Relay server';

  @override
  String get s72da730a42 => 'Servicio remoto: conectado';

  @override
  String get s421f161f5b => 'Conectarse al servicio remoto...';

  @override
  String get s88e2b1dad5 =>
      'No hay conexión con el servicio remoto – reintentando automáticamente. Compruebe la conexión a Internet.';

  @override
  String get scc0cccf89d => 'Apagado';

  @override
  String get sa1d085d92c => 'El puente no tiene dashboards para copiar.';

  @override
  String sa13ef6f8d9(String p0) {
    return 'Copied: $p0 dashboards';
  }

  @override
  String sab5e7202f5(String p0) {
    return 'Conectado a \"$p0\"!';
  }

  @override
  String get s30f06b7fb0 =>
      'Ahora puede controlar su hogar desde cualquier lugar. Copia los paneles y dispositivos del puente de inicio a este dispositivo también?';

  @override
  String get s641263ce18 => 'No, gracias';

  @override
  String get sa7a6c0fc2d => 'no es un código Molaplan';

  @override
  String get se2ecf1935a => 'Conectar a casa';

  @override
  String get s410655fd47 => 'Cómo conectarse';

  @override
  String get s3a141e0c32 =>
      'En el puente de inicio (tabla o PC en casa) abra Molaplan → Ajustes → Acceso remoto → Haga de este dispositivo el puente de inicio.';

  @override
  String get sc7c83b2f58 =>
      'Presione \"Pair un teléfono\" allí. Aparece un código QR y 6 dígitos.';

  @override
  String get s35284509d4 =>
      'Escríbase el código QR o escriba los dígitos a continuación.';

  @override
  String get s66bb65d8e8 => 'Escanear el código QR';

  @override
  String get se97cc157ef => 'o escriba el código';

  @override
  String get s643434044c =>
      'Al usar el código, presione \"Aceptar\" en el puente de inicio también.';

  @override
  String get s9753766742 =>
      'Presione \"Acepto\" en la pantalla del puente casero...';

  @override
  String get s50e49dd1df => 'Apunte la cámara en el código QR';

  @override
  String s5d717bb2c5(String p0) {
    return 'No se puede utilizar la cámara ($p0). Permitir acceso a la cámara o escribir el código.';
  }

  @override
  String s7132345f20(String p0) {
    return 'Dispositivo \"$p0\" conectado!';
  }

  @override
  String get sb38b582dab => 'Puente de casa';

  @override
  String get se2e2af02ac =>
      'El puente casero es un dispositivo que se mantiene en casa, por ejemplo una vieja tableta o un PC. Cuando usted está lejos, los comandos de su teléfono se encriptan a través de él a sus dispositivos.';

  @override
  String get sd64f52490d => 'Mantenlo en el cargador y en el Wi-Fi casero.';

  @override
  String get sbb23f25581 =>
      'Mantén a Molaplan abierto. La pantalla se mantiene mientras el puente está encendido.';

  @override
  String get sbfed096278 => 'Utilice este dispositivo como puente casero';

  @override
  String get s13995350ed => 'Vincular un teléfono';

  @override
  String get s6a74454a98 => 'Dispositivos pares';

  @override
  String get s1e4fc2e7fe => 'Nada todavía. Presione \"Pair un teléfono\".';

  @override
  String get s7ea55c5834 => 'Añadido';

  @override
  String sfd8d693d04(String p0) {
    return '¿Retirar \"$p0\"?';
  }

  @override
  String get s84572f642e =>
      'El dispositivo ya no puede conectarse remotamente. Puede ser emparejado de nuevo.';

  @override
  String get sc58a7d7121 => 'Nombre de la casa';

  @override
  String get s9715416100 => 'Escanear con el teléfono';

  @override
  String get sf54c6d871c =>
      'En el teléfono: Molaplan → Ajustes → Acceso remoto → Conectar este dispositivo a casa';

  @override
  String get sf7fa9632f3 => 'Válido para';

  @override
  String get s5378bb3f05 => '¿Aceptar este dispositivo?';

  @override
  String s1d8bb7b0a6(String p0) {
    return '\"$p0\" quiere control remoto de su casa. Aceptar sólo si es su propio o el dispositivo de un miembro de la familia que acaba de entrar en el código.';
  }

  @override
  String get sa04c218f82 => 'Rechazar';

  @override
  String get sdfaf8c242b => 'Aceptar';

  @override
  String get s1cf33c1fbc => 'Valor';

  @override
  String get s86029171be => 'Encender/apagar';

  @override
  String get s4ddce888df => 'Botón / atajo';

  @override
  String get s357fc9c3fe => 'Slider / setpoint';

  @override
  String get seeb6c38c8e => 'Cámara';

  @override
  String get s14da6beba5 => 'Muestra una lectura, por ejemplo, temperatura.';

  @override
  String get se4b1d203df => 'On/off, p. ej. una luz o alarma.';

  @override
  String get sc2197ab417 => 'Un toque hace una o muchas cosas.';

  @override
  String get sd611704caf => 'Ajusta un valor, por ejemplo, la temperatura.';

  @override
  String get sacfc0c0b41 => 'Muestra una imagen de cámara.';

  @override
  String get s7172c54c2c => 'Mantiene la temperatura en el valor fijado.';

  @override
  String get s76e7a995de => 'Valor leído';

  @override
  String get sc5edd6d3d1 => 'Nueva tarjeta';

  @override
  String get sa684fd0716 => 'Editar tarjeta';

  @override
  String get s8a8673aafe => 'Título';

  @override
  String get scf37cbeda8 => 'Icono';

  @override
  String get sa444aab286 => 'Automático';

  @override
  String get sfeab9bd26f => 'Width';

  @override
  String get s58be670598 => 'Altura';

  @override
  String get sea30815e6a =>
      'Los ajustes de baldosas técnicos aparecen cuando enciende \"Advanced\" en Ajustes.';

  @override
  String get s382afc832f => 'Fuente del Estado';

  @override
  String get s581aee3e96 => 'Opcional: de dónde se lee el estado actual.';

  @override
  String get se6b18b17d9 => 'Intervalo de la encuesta (s, 0 = ninguno)';

  @override
  String get s01f2b1ee0c =>
      'MQTT, Home Assistant and WebSocket update live without polling.';

  @override
  String get s937448ecf5 => 'Prueba de lectura';

  @override
  String get s5cbdea7f7e => 'Visualización';

  @override
  String get se6af4b33df => 'Unidad';

  @override
  String get sd5498697da => 'Decimales';

  @override
  String get s4f7007db78 => 'Nombres de valor';

  @override
  String get s4aae179c52 => '0=Off;1=Home;2=Away';

  @override
  String get s0c12fda7ca => 'Toggle comandos';

  @override
  String get s3a9d9e16ef => '\"En\" valores (comma separado, vacío = auto)';

  @override
  String get s1509c5a2a6 => 'ON comando';

  @override
  String get s2a1e131afd => 'OFF command';

  @override
  String get s0201de52c0 =>
      '{\'{value}\'} en el comando es reemplazado por el valor deslizante.';

  @override
  String get sc30c9a7e51 => 'Paso';

  @override
  String get s4d6451a63a => 'Establecer el comando';

  @override
  String get sa4082e1a79 => 'Comandos (corridos en orden)';

  @override
  String get s467488e572 =>
      'Un acceso directo puede controlar varios dispositivos en secuencia, con retrasos.';

  @override
  String get sad43973fb3 => 'Añadir comando';

  @override
  String get sdaef43c622 => 'Solicitar confirmación';

  @override
  String get s5210a5ad23 => 'Conexión';

  @override
  String get s96705fc3df => 'Comando enviado';

  @override
  String get sb41db1e809 => 'Pruébalo';

  @override
  String get s77d2309fd5 => 'Retraso antes (ms)';

  @override
  String get sc0f5a14d2b => 'umbrales de color (valor ≥ límite → color)';

  @override
  String get scd65d31d4c => 'Limitación';

  @override
  String get s30a2c0f460 => 'Añada el umbral';

  @override
  String get s4226eb046f => 'Deshacer';

  @override
  String get sd5cb601286 => 'Tailscale (fácil VPN)';

  @override
  String get s0aa851cfb4 =>
      'Gratis para uso personal. Su teléfono y su hogar actúan como una red – Molaplan trabaja con las mismas direcciones que en casa.';

  @override
  String get s444ca5d58f =>
      'Bien si tienes un PC siempre conectado, Raspberry Pi o Home Assistant en casa.';

  @override
  String get sec7b4d1d7a =>
      'Crear una cuenta de Tailscale en tailscale.com (Google, Microsoft o Apple-in).';

  @override
  String get s178c57446d =>
      'Instala Tailscale en el dispositivo siempre en casa. En Home Assistant: Settings → Add-ons → Tailscale.';

  @override
  String get s4faf83aa13 =>
      'Encienda el \"rutador de subred\" allí e ingrese su red de inicio, por ejemplo 192.168.1.0/24. Entonces todos los dispositivos de su hogar son accesibles.';

  @override
  String get s721719c0e1 =>
      'Aprobar la ruta en la consola de administración Tailscale (Machines → dispositivo → Editar configuración de la ruta).';

  @override
  String get s921f981bda =>
      'Instala la aplicación Tailscale en tu teléfono y accede con la misma cuenta.';

  @override
  String get s8ae7e7b2a4 =>
      '¡Hecho! Molaplan utiliza las mismas direcciones que en casa. Nada más que cambiar.';

  @override
  String get se92301ff0a => 'https://tailscale.com/download';

  @override
  String get sf6270ae66c => 'https://tailscale.com/kb/1019/subnets';

  @override
  String get s57f0b61334 => 'WireGuard (reuter VPN)';

  @override
  String get sb9bb49ab92 =>
      'Si su router admite WireGuard (por ejemplo ASUS, FRITZ!Box, UniFi, OpenWrt), su teléfono se une a la red de inicio directamente.';

  @override
  String get s986d264604 =>
      'Bien si el router tiene WireGuard y su conexión tiene una dirección IP pública.';

  @override
  String get sf24b16dc12 =>
      'Abra la configuración del router y busque \"servidor VPN\" → \"WireGuard\".';

  @override
  String get s1e5d1eb832 =>
      'Habilitar el servidor y añadir un nuevo dispositivo (peer) para el teléfono.';

  @override
  String get s8e0252a2b4 =>
      'El router muestra un código QR. Instala la aplicación WireGuard en el teléfono y escríbela.';

  @override
  String get s4b3740b727 =>
      'Comprueba que \"Protectores permitidos\" incluye la red doméstica (por ejemplo, 192.168.1.0/24).';

  @override
  String get sd2e8523b28 =>
      'Cambiar el VPN en el teléfono – Molaplan funciona como en casa.';

  @override
  String get saa17c5a456 => 'https://www.wireguard.com/install/';

  @override
  String get se5960424ea =>
      'Muchas conexiones de banda ancha móvil (4G/5G home internet) no tienen IP pública (CGNAT) y WireGuard entonces no se puede llegar desde fuera. Use acceso remoto Molaplan o Tailscale en su lugar.';

  @override
  String get sab2dfe387b => 'Home Assistant Cloud (Nabu Casa)';

  @override
  String get s2e0586b37e =>
      'Una suscripción mensual pagada de los fabricantes de Home Assistant. Da una dirección remota segura a Home Assistant.';

  @override
  String get s534e7ec95e =>
      'Bien si sus dispositivos ya están en Home Assistant.';

  @override
  String get s0f7533967d =>
      'En Home Assistant: Settings → Home Assistant Cloud → iniciar el ensayo o iniciar sesión.';

  @override
  String get s2e60dd8178 => 'Gire \"Remote control\" en.';

  @override
  String get s7a73024451 =>
      'Copiar la dirección remota, que parece: https://abcd1234.ui.nabu.casa';

  @override
  String get sd4873612f7 =>
      'En Molaplan: Conexiones → Home Assistant → cambiar la dirección a la dirección remota. El token se mantiene igual.';

  @override
  String get s15223b0e32 =>
      '¡Hecho! Las baldosas de Home Assistant ahora funcionan en todas partes.';

  @override
  String get s9b3201b1fa => 'https://www.nabucasa.com/';

  @override
  String get s60e7067815 =>
      'Esto sólo cubre los dispositivos controlados a través de Home Assistant. Para otros (Modbus, cámaras directamente) utilizan el acceso remoto Molaplan o una VPN.';

  @override
  String get s8e0d0a2d4e => 'Cloud MQTT (por ejemplo, HiveMQ Cloud)';

  @override
  String get sd0fff65292 =>
      'Dispositivos y Molaplan hablan a través del mismo servidor en la nube. HiveMQ Cloud tiene un nivel gratuito que es suficiente para el uso doméstico.';

  @override
  String get s7350b9f98b =>
      'Bien para dispositivos MQTT: Tasmota, ESPHome, Shelly, Zigbee2MQTT, tus propias tablas ESP.';

  @override
  String get s59b3c7d246 =>
      'Cree una cuenta gratuita en consola.hivemq.cloud y cree un clúster libre (gratuito/sin soporte).';

  @override
  String get s04fe436d1e =>
      'Bajo \"Access Management\" crea un nombre de usuario y contraseña.';

  @override
  String get sdf0075eab5 =>
      'Copiar la dirección del servidor (por ejemplo, abcd.s1.eu.hivemq.cloud). El puerto es de 8883 con TLS encendido.';

  @override
  String get s9e9be6fc33 =>
      'Ponga este servidor, nombre de usuario y contraseña en la configuración de MQTT de sus dispositivos (TLS en).';

  @override
  String get s90f1cb151b =>
      'En Molaplan: Conexiones → MQTT → dirección, puerto 8883, TLS on, nombre de usuario y contraseña.';

  @override
  String get s77bf29f2f5 => 'https://console.hivemq.cloud/';

  @override
  String get safd2cd2b7b =>
      'Elija una contraseña fuerte: cualquiera que sepa que puede controlar sus dispositivos.';

  @override
  String get s9557c0ef28 => 'Guías de acceso remoto';

  @override
  String get sf4d7957b78 => 'Más fácil: acceso remoto Molaplan';

  @override
  String get s8032085166 =>
      'Sin cuentas, sin configuración de router. Sólo necesita una tableta o PC que se mantenga en casa.';

  @override
  String get sd9b48e01fc => 'Otras formas';

  @override
  String get sfe551fd431 => 'Guías de dispositivos';

  @override
  String get sa35e37b4b4 =>
      'Mitsubishi CN105, Daikin S21/X50A (Faikin), Panasonic CN-CNT, Toshiba. Se encuentra automáticamente.';

  @override
  String get scb28b11e70 => 'Nueva vista';

  @override
  String get s1f9799af4e => 'e.g. Cottage';

  @override
  String get s3a13f9d077 => 'Rename dashboard';

  @override
  String get sa5bf37213b => '¿Supir el panel de control?';

  @override
  String s10671afc00(String p0, String p1) {
    return '\"$p0\" y sus tablas $p1 serán eliminadas.';
  }

  @override
  String s897761b5f4(String p0) {
    return 'Dashboard \"$p0\" eliminado';
  }

  @override
  String get scc5cf9957d => 'Elija el tipo de azulejos';

  @override
  String get s7cf6340503 => 'Nuevo dispositivo con tarjetas listas';

  @override
  String get se6ca707cf3 => 'Más fácil: Shelly, ESP32-CAM, Home Assistant...';

  @override
  String get s0789f5f14f => 'DASHBOARDS';

  @override
  String get s59622d792b => 'Renombrar';

  @override
  String get sfb3e3c456c => 'Suprímase el tablero';

  @override
  String get scdfd80f963 => 'Añadir tarjeta';

  @override
  String get s71af34b8e9 => 'Vista vacía';

  @override
  String get s6a210970eb =>
      'Las fichas del dispositivo aparecen aquí: temperaturas, interruptores, cámaras y atajos. Comience añadiendo un dispositivo.';

  @override
  String get s4229fb4103 => 'Añade tu primer dispositivo';

  @override
  String get s147f47be4c => 'Añadir tarjeta';

  @override
  String get sf67e0d5752 => '¿Eliminar la tarjeta?';

  @override
  String s97f46743e0(String p0) {
    return 'Tile \"$p0\" eliminado';
  }

  @override
  String get sb8934a5835 => 'Consumo eléctrico';

  @override
  String get s5409dc748f => 'No se cuenta';

  @override
  String get sf0bbcc217b => 'Toda la vivienda';

  @override
  String get s0ad1897b28 => 'Medidor del aparato';

  @override
  String get s99268b5a6c =>
      'Toda la vivienda = contador principal. Medidor del aparato = un aparato (se muestra como parte del total, nunca se cuenta dos veces).';

  @override
  String get se1174af557 => 'Parte del medidor (opcional)';

  @override
  String get s9773c92c92 => 'Energía y costes';

  @override
  String get s43dead6994 => 'Contrato eléctrico';

  @override
  String get sef4d24cdd4 => 'Día';

  @override
  String get sa62dd794ce => 'Mes';

  @override
  String get s6b2ebe5aca => 'Elige primero tus medidores';

  @override
  String get sde41f2fac9 =>
      'Marcar abajo qué medidor mide todo el sitio y cuáles dispositivos individuales.';

  @override
  String get s4ad000d885 => 'IVA incl.';

  @override
  String get s9e214b6e88 => 'sin IVA';

  @override
  String get s73771d252c => 'Total de aparatos medidos';

  @override
  String get s22d03356a9 => 'Otros consumos';

  @override
  String get s48b08c5f5a => 'Cuotas mensuales (energía + peajes)';

  @override
  String get s286e1cfb54 => 'Total';

  @override
  String get s2e8700e0cf =>
      'Parte del uso no tenía precio (el precio del spot faltaba).';

  @override
  String get sbbd89fbc05 =>
      'El uso se registra mientras la aplicación está abierta (todo el tiempo en la tableta de inicio).';

  @override
  String get s64382718ff => 'Medidores';

  @override
  String get s9a3a0d414e =>
      'No hay tarjetas de alimentación o energía (W, kW, Wh, kWh). Añadir por ejemplo un medidor de Shelly.';

  @override
  String get sdb0484d728 => 'Guardado';

  @override
  String get se80021e22a =>
      'Copie los precios de su factura. Introduzca con o sin IVA – los costos se muestran a ambos lados.';

  @override
  String get sfb62156afe => 'Zona de precio';

  @override
  String get s1762fb70a7 => 'Energía';

  @override
  String get s2ed3e3cf28 => 'Precio spot';

  @override
  String get s5d1dd0f675 => 'Fijo';

  @override
  String get sedb38796fb => 'Noche/día';

  @override
  String get s0774cea15a => 'Margen';

  @override
  String get s63370fe61a => 'Precio de la energía';

  @override
  String get s50a7dd89c6 => 'Energía de día';

  @override
  String get sdeaa5ad900 => 'Energía de noche';

  @override
  String get se93c7bcd86 => 'Cuota mensual (energía)';

  @override
  String get sb7937e4b91 => 'Peajes';

  @override
  String get s0f89840226 => 'Tarifa única';

  @override
  String get sa768f1b352 => 'Precio de peajes';

  @override
  String get s9e5dde22cb => 'Peajes de día';

  @override
  String get sdf7a4fd2e3 => 'Peajes de noche';

  @override
  String get s4df0aee067 => 'Cuota mensual (peajes)';

  @override
  String get s4c59c90975 => 'La noche empieza';

  @override
  String get s84decd042b => 'La noche termina';

  @override
  String get s90c26f1e37 => 'Impuestos';

  @override
  String get s222cb348a0 => 'Impuesto eléctrico';

  @override
  String get sbe412dcaa6 => 'IVA';

  @override
  String get s43b55c13c5 => 'La búsqueda falló. Revisa la conexión.';

  @override
  String get s171834ca33 => 'Ubicación de casa';

  @override
  String get s6f6c2fe37a =>
      'El pronóstico del tiempo (Open-Meteo) ayuda a precalentarse antes del frío. La ciudad es suficiente.';

  @override
  String get s5f663978d6 => 'Localidad';

  @override
  String get s7be6460c54 => 'p. ej. Tampere';

  @override
  String get s1576b70590 => 'Uso de electricidad, costes, contrato y tiempo.';

  @override
  String get sa6212aaeb4 => 'Ubicación';

  @override
  String get sa0d8c62e5a => 'No hay ningún comando configurado';

  @override
  String get s1e5d696a26 => '¿Ejecutar este comando?';

  @override
  String get s1df6e2eaa7 => 'PIN';

  @override
  String get secab66c046 => 'Recuerde en este dispositivo';

  @override
  String get s10bf4eab8e =>
      'Almacenado encriptado en este dispositivo solamente. Por defecto el PIN no se almacena.';

  @override
  String get s912ea5d2ec => 'Enviar';

  @override
  String get s856418521a => 'No hay comandos configurados';

  @override
  String sdfa66ee201(String p0) {
    return '$p0: sent';
  }

  @override
  String get s12fc3810a5 => 'Enviado – esperando la respuesta...';

  @override
  String get sd1c7d49360 => 'Respuesta a la respuesta';

  @override
  String get s38ac222392 => 'Valor';

  @override
  String get s29fae6a0e8 => 'Control por precio activado';

  @override
  String get sbfe79d1f5f => 'Actualizado';

  @override
  String get s25580038cb => 'Separación de PIN';

  @override
  String get sf50c488b24 => 'Olvídate de PIN salvado';

  @override
  String get safe0429a90 => 'Control por precio';

  @override
  String get sf3d644dd4c => 'Aprender un botón del mando';

  @override
  String get sfb1a18d11f => 'Actualizar';

  @override
  String get s4cbe24240f => 'Encendido';

  @override
  String get sdc398885dc => 'Ajustes avanzados';

  @override
  String get s5d477f3cd8 => 'Normalmente no necesitas estos';

  @override
  String get s2315e0e739 => 'p. ej.';

  @override
  String get s4dab2d409b => 'Configuración de las exportaciones';

  @override
  String get s149c1e54d6 => 'Configuración exportada';

  @override
  String get s35f445793b => 'Configuración de importación';

  @override
  String get sd55be829e3 => '¿Reemplazar la configuración actual?';

  @override
  String get s852dd1795e =>
      'Todas las conexiones y paneles actuales son reemplazadas por el contenido del archivo.';

  @override
  String get s580678cb10 => 'Importar';

  @override
  String get s5f2ec17730 => 'Configuración importada';

  @override
  String get sa87fff54f3 => 'La importación falló';

  @override
  String get s2fd2bfedb8 => 'Cuenta';

  @override
  String get s4c0ff416ab =>
      'Las mismas casas y fichas en todos tus dispositivos.';

  @override
  String get scc7e418ee3 =>
      'Inicie sesión para tener las mismas casas, dispositivos y fichas en PC, tableta y teléfono. Opcional.';

  @override
  String get s9bb545e9b3 => 'Inicia sesión o crea una cuenta';

  @override
  String get s21f870dbc2 =>
      'Muestra configuración técnica: conexiones (HTTP, MQTT, Modbus...), cargas de pago, caminos JSON y fuentes de baldosas. La mayoría de la gente no necesita estas.';

  @override
  String get saec69088a5 => 'Controla tu casa desde fuera también.';

  @override
  String get scc3d01ee5e => 'Guías: VPN, Nabu Casa, nube MQTT';

  @override
  String get s90ba544719 => 'Ayuda';

  @override
  String get sb915c42792 => 'Mostrar el guía de arranque';

  @override
  String get sd337a7ddd5 => 'Copia de seguridad y transferencia';

  @override
  String get s07c1048b4f =>
      'Exportar la configuración a un archivo JSON e importarlo en otro dispositivo (por ejemplo, PC → teléfono).';

  @override
  String get s2f797098e7 => 'Incluye contraseñas y fichas';

  @override
  String get s26f72949e3 =>
      'El archivo entonces no está encriptado – mantenerlo a salvo.';

  @override
  String get sdb12678e52 => 'Exportar';

  @override
  String get s34686ffb09 => 'Ejemplo';

  @override
  String get s412c666544 =>
      'Agregue un dashboard de ejemplo (camera, alarma, luces, ventilación). Reemplace las direcciones con el suyo.';

  @override
  String get sec02c7c071 => 'Añadir vista de ejemplo';

  @override
  String get s522d6584c5 => 'Buscar actualizaciones';

  @override
  String get sd178a1d809 =>
      'Su propia terminal de control: HTTP, MQTT, Modbus TCP, Home Assistant, cameras, WebSocket, TCP y UDP. Sin una cuenta, todos los ajustes permanecen en este dispositivo.';

  @override
  String get se455dc672b => 'Paso';

  @override
  String get s3ddd2678bf => 'Saltar la guía';

  @override
  String get s171ac59e67 =>
      'Elija su dispositivo abajo. Sólo llena su dirección – el resto está hecho para usted.';

  @override
  String get s907220900d => 'Bienvenido a Molaplan';

  @override
  String get se722dfcec9 =>
      'Molaplan es el propio panel de control de tu casa. Pones exactamente los dispositivos y botones que necesitas.';

  @override
  String get scbac938ead => 'Mira todo de un vistazo';

  @override
  String get se25f930e31 =>
      'Temperaturas, luces, alarma y cámara en una sola vista.';

  @override
  String get s3e450dba98 => 'Control con un grifo';

  @override
  String get sdda6a3f06e =>
      'Luces encendidas, aumentar la ventilación, o un botón \"Dejar casa\" que hace muchas cosas a la vez.';

  @override
  String get sbcac0cd35a => 'La misma casa en todos los dispositivos';

  @override
  String get sd43d517cc7 =>
      'Inicie sesión si lo desea, y PC, tableta y teléfono mostrar el mismo hogar. Las contraseñas están cifradas en su dispositivo. No se necesita ninguna cuenta.';

  @override
  String get s70fff97e97 => 'Ya tengo una cuenta de Molaplan – firma';

  @override
  String get sd6561a08ca => 'Empecemos';

  @override
  String get se5be2a8386 => 'Tus tarjetas están listas';

  @override
  String get s8162694dbe => 'Añade tu primera tarjeta';

  @override
  String get s7b2a30b77c =>
      'Estas fichas fueron hechas para tu dispositivo. Puedes cambiarlas y arreglarlas más tarde.';

  @override
  String get s39e163fa49 =>
      'Una baldosa muestra información o controla un dispositivo. Elige qué tipo de baldosas:';

  @override
  String get s4bfb026e45 => 'Lo haré más tarde';

  @override
  String get s3f0351473c => '¿Controla tu casa desde fuera también?';

  @override
  String get s6fe6fe631f =>
      'En casa todo funciona ya. Desde fuera necesita un dispositivo siempre en casa (una vieja tableta o un PC) – ninguna configuración del router, ninguna cuenta.';

  @override
  String get sb599b7432f => 'El acceso remoto está encendido.';

  @override
  String get s33a294d472 => 'Este dispositivo es el puente casero.';

  @override
  String get s4aa8cce504 => 'No ahora – solo en casa';

  @override
  String get sd3c370ca52 => '¡Listo!';

  @override
  String get s1359035b73 => 'Pulsa una baldosa';

  @override
  String get sfd26c8e50b =>
      'Un interruptor se mueve, un botón ejecuta su comando.';

  @override
  String get s416c8184a7 => 'Botón de lápiz en la parte superior';

  @override
  String get s2ba275defe =>
      'Editar, añadir, eliminar y arrastrar las fichas alrededor.';

  @override
  String get se872eeb0f5 => 'Long-press a tile';

  @override
  String get s63496941fc => 'Ver detalles y una explicación si algo está mal.';

  @override
  String get s080be778d5 =>
      'Encuentra esta guía, acceso remoto y copias de seguridad allí.';

  @override
  String get sae0fae7127 => 'Ve a mi salpicadero';

  @override
  String get s3d43664fcc => 'WebSocket';

  @override
  String get sfcbb753f53 => 'URL';

  @override
  String get s81479e1555 => 'Headers (Name: value per line)';

  @override
  String get s5811b38d7b => 'Token (Authorization: Bearer)';

  @override
  String get sd512dbbfc7 => 'Mensaje en conexión';

  @override
  String get s2c4fd261e2 => 'Permitir certificado autosignificado';

  @override
  String get s4d089aab74 => 'Filtro (mensaje contiene)';

  @override
  String get s55c951a8ad => 'JSON path';

  @override
  String get s10813e25b3 => 'Regex (grupo 1)';

  @override
  String get s4a282cd247 => 'Solicitud de mensaje (sentido al leer)';

  @override
  String get sbeef545d37 => 'Mensaje ({\'{value}\'} = valor)';

  @override
  String get s0477f24b6b => 'HTTP / REST';

  @override
  String get s3102ae3a16 => 'Base URL';

  @override
  String get s38d0517a8d => 'Autenticación';

  @override
  String get sed995f57b8 => 'Usuario';

  @override
  String get s65e35b7cc4 => 'Token';

  @override
  String get s51510ae27a => 'Cabeceras extra (Nombre: valor por línea)';

  @override
  String get s361419c448 => 'Timeout (s)';

  @override
  String get sf235ce5ec0 => 'Método';

  @override
  String get s484291707c => 'Camino';

  @override
  String get s54c8aed8bc => 'Cuerpo';

  @override
  String get s5c5e9b662c => 'Cuerpo ({\'{value}\'} = valor)';

  @override
  String get s8e82ca13cf => 'Content-Type';

  @override
  String s3c045f21ee(String p0, String p1, String p2) {
    return 'Tested: GET $p0 (base address, $p1 bytes, $p2 ms).';
  }

  @override
  String get s7797602869 =>
      'No se enviaron órdenes y no se probaron caminos de azulejos.';

  @override
  String sbf349dfcbd(String p0, String p1) {
    return 'HTTP $p0: el dispositivo respondió pero rechazó el login. Compruebe el nombre de usuario, contraseña o ficha. $p1';
  }

  @override
  String s3bd10f0ae2(String p0, String p1) {
    return 'HTTP $p0: el dispositivo respondió con un error de servidor. $p1';
  }

  @override
  String s2a7fa26dd6(String p0, String p1) {
    return '✓ El dispositivo respondió a $p0 (HTTP 404: ninguna página en la dirección base – normal para muchos dispositivos). La conexión funciona. $p1';
  }

  @override
  String sb2821916bc(String p0, String p1, String p2) {
    return '✓ Trabajos de conexión: HTTP $p0. $p1 $p2';
  }

  @override
  String get sad3975b3c1 => 'Cámara (MJPEG / JPEG)';

  @override
  String get s1534821f4a => 'Base de la cámara URL';

  @override
  String get se995a6862d => 'Modo';

  @override
  String get s4f356d158a => 'Refresh (s, snapshot)';

  @override
  String get sca7e088857 => 'Precio de la electricidad';

  @override
  String get s2525f9a4f5 =>
      'Finlandia es una zona (FI). En Suecia y Noruega depende de dónde vives.';

  @override
  String get s8f4a683abf => 'IVA %';

  @override
  String get s1c7d76a774 => 'El IVA de su país.';

  @override
  String get se49d0fba92 => 'Margen del comercializador (c/kWh)';

  @override
  String get s20a5e2936a => 'Mando de contrato sin IVA.';

  @override
  String get s923f9739de => 'Peajes + impuestos (c/kWh)';

  @override
  String get s2a3498fb0f =>
      'De tu factura, incl. IVA. Deja 0 solo para energía.';

  @override
  String get s515da3a9dd => 'Servidor de precio';

  @override
  String get s98cc9f1c14 =>
      'Los precios del servidor de Molaplan son de fuentes abiertas.';

  @override
  String get s271885dc8b => 'Qué mostrar';

  @override
  String get s46282f452b => 'ahora = precio actual, gráfico = hoy y mañana.';

  @override
  String get s2f754e8ab4 => 'Todavía no hay precios para hoy.';

  @override
  String get sd575462da3 => 'mañana ';

  @override
  String get s18faad19ed => 'No hay precio por ahora.';

  @override
  String get s29178b43f4 => 'El precio de electricidad es sólo lectura.';

  @override
  String get s1a707f2788 => 'Mañana: sí.';

  @override
  String get sb85af981c1 =>
      'Mañana: aún no (publicado alrededor de las 14:00).';

  @override
  String s6270faf138(String p0, String p1, String p2, String p3) {
    return '✓ Precios para $p0 ($p1 ranuras, $p2 min, source $p3).';
  }

  @override
  String get se1bd60873c => 'MQTT';

  @override
  String get s85b9781bb7 => 'Broker host';

  @override
  String get s800d13debd => 'Puerto';

  @override
  String get s49fa57061a => 'TLS';

  @override
  String get s0fcef98aad => 'Use WebSocket (ws:// o wss://)';

  @override
  String get s5089c65c1f => 'ID de cliente (vacío = auto)';

  @override
  String get s9372a6f755 => 'Keep alive (s)';

  @override
  String get sd373a99107 => 'Tema de estado';

  @override
  String get s518c8aa712 => 'Tema del comando';

  @override
  String get s120726c79a => 'Carga útil ({\'{value}\'} = valor)';

  @override
  String get s3660228d11 => 'QoS';

  @override
  String get s1b07c9ba3d => 'Retain';

  @override
  String s91c3d72d1e(String p0) {
    return 'fan $p0';
  }

  @override
  String get s40032ddea9 => ', swing';

  @override
  String get s7068e8892e =>
      'Código desconocido sin datos brutos. Habilitar datos brutos en Tasmota (SetOption581) e inténtelo de nuevo.';

  @override
  String get s6207a45bff => 'Bomba de calor IR (bomba de calor)';

  @override
  String get s859c2e7734 => 'Blaster firmware';

  @override
  String get s3f8d3fb444 =>
      'tasmota_http = Tasmota (tasmota-ir) por IP. tasmota_mqtt = Tasmota a través de un broker MQTT. esphome = ESPHome climate_ir. http/mqtt = otro blaster con tus propias plantillas.';

  @override
  String get s38471ae691 => 'Dirección de Blaster';

  @override
  String get sda91fafa54 => 'Dirección IP del blaster IR (Tasmota o ESPHome).';

  @override
  String get sf9220a3e4d => 'Protocolo de marca IR';

  @override
  String get s423f2576c4 =>
      'Tasmota IRhvac vendedor, por ejemplo MITSUBISHI_AC, PANASONIC_AC, DAIKIN. Si no pasa nada, prueba otro protocolo de la misma marca.';

  @override
  String get s74ff2fd8a8 => 'Modelo (opcional)';

  @override
  String get sef4c0e5d90 =>
      'Número de modelo IRhvac para algunas marcas. Dejar vacío si no está seguro.';

  @override
  String get s8e7962c184 => 'Tema de Tasmota';

  @override
  String get s5ae4cc50db =>
      'MQTT sólo: de Tasmota (Configuración → MQTT → Tema).';

  @override
  String get sed30580f59 => 'Dirección de corredores de MQTT';

  @override
  String get s744ce256bb => 'MQTT sólo: la máquina que ejecuta el corredor.';

  @override
  String get se6754df705 => 'puerto MQTT';

  @override
  String get sbfc8ee6c86 => 'Usuario';

  @override
  String get s711670d91a => 'MQTT o usuario web.';

  @override
  String get s3bbd70773d => 'Deja vacío si no es necesario.';

  @override
  String get s443fe6f350 => 'ESPHome climate id';

  @override
  String get s62feae1a9f => 'ESPHome solamente: el objeto climático id.';

  @override
  String get se0efd6dfb3 => 'URL del comando (otro blaster)';

  @override
  String get s5366cbd4df =>
      'http solamente: URL que recibe el estado completo.';

  @override
  String get sce533db7c1 => 'Plantilla de carga de pago (otro blaster)';

  @override
  String get s0fa691e7c7 =>
      'Cuerpo http o mqtt payload. Vacío = IRhvac JSON ({\'{json}\'}).';

  @override
  String get s8567c5faa6 =>
      'sumario = estado completo como texto. habitación = sensor de temperatura del interruptor. Otros = último ajuste enviado.';

  @override
  String get sdd8cd8132c => 'Qué cambiar';

  @override
  String get s2e8b846390 =>
      'Todo el estado es enviado a la vez. El valor viene de la baldosa o \"Value\".';

  @override
  String get sb517d97868 =>
      'E.g. calor, fresco, auto, seco, ventilador o encendido/off. Vacío = valor de baldosas.';

  @override
  String get sda4a1b2eee => 'Código de aprendizaje';

  @override
  String get s0cfc723aa2 => 'Lleno cuando guardas un botón remoto aprendido.';

  @override
  String get s3f26cb7602 => 'ESPHome botón';

  @override
  String get sc71964f422 =>
      'ESPHome solamente: id del botón de plantilla para un código aprendido.';

  @override
  String get s852a166240 => 'Falta la dirección de Blaster.';

  @override
  String get s75ce01c354 => 'Tasmota necesita la contraseña web.';

  @override
  String sf9d84ad23c(String p0) {
    return 'Tasmota no sabe $p0. Instalar la construcción de tasmota-ir.';
  }

  @override
  String sff167aa9a6(String p0) {
    return 'Tasmota rechazó el mandamiento: $p0';
  }

  @override
  String s385c6a9a2d(String p0) {
    return 'Vendedor desconocido \"$p0\".';
  }

  @override
  String sb4ea2389cb(String p0) {
    return 'ESPHome climate \"$p0\" no se encuentra.';
  }

  @override
  String get s34deda2c72 => 'Falta la URL del comando.';

  @override
  String get s04e4777aea => 'Falta la temperatura.';

  @override
  String get sfce1a094cb => 'No hay sensor de temperatura en el interruptor.';

  @override
  String s4536eb33dd(String p0) {
    return 'No se recibió temperatura.';
  }

  @override
  String get s9b5bbfa2c6 =>
      'Temperatura de la habitación sólo desde Tasmota/ESPHome.';

  @override
  String get s5acc16dafb => 'RF433 necesita Tasmota.';

  @override
  String get s8478662ad1 => 'Los códigos aprendidos necesitan Tasmota.';

  @override
  String s9f8263b5a0(String p0, String p1) {
    return 'ESPHome botón \"$p0\" no se encuentra.';
  }

  @override
  String s3296e8d7e7(String p0) {
    return 'No hay ningún código dentro $p0 s. Puntee el control remoto en el volador (menos de 1 m) y presione de nuevo.';
  }

  @override
  String get s1e73ba395d => 'RF433 necesidades de aprendizaje Tasmota.';

  @override
  String get scc47b4b225 =>
      'Aprender trabaja con los blasters de Tasmota y ESPHome.';

  @override
  String s96adaaf2b6(String p0, String p1, String p2) {
    return '✓ Tasmota respondió (versión $p0). Testado: Estado 0 a $p1. Nada fue enviado a la bomba de calor.';
  }

  @override
  String sfce5c770f1(String p0) {
    return 'Broker OK pero Tasmota \"$p0\" no respondió.';
  }

  @override
  String s2c3b95a054(String p0) {
    return '✓ Tasmota \"$p0\" respondió vía MQTT. Nada enviado a la bomba de calor.';
  }

  @override
  String scf9ead3297(String p0, String p1, String p2, String p3) {
    return '✓ ESPHome climate \"$p0\" encontrado. Nada fue enviado.';
  }

  @override
  String get s8ad50358b9 =>
      'No hay prueba para otros voladores: IR es de una manera. Presione la baldosa de energía y observe la bomba de calor.';

  @override
  String s3b476099a2(String p0) {
    return 'El dispositivo respondió HTTP $p0. ¿Está habilitado web_servidor en ESPHome?';
  }

  @override
  String sd44aec7380(String p0) {
    return 'Sin respuesta de $p0.';
  }

  @override
  String s120026628c(String p0) {
    return 'Could not reach $p0.';
  }

  @override
  String get s43c9b88580 => 'Auto';

  @override
  String get sa3e8beed42 => 'Calor';

  @override
  String get s6c9668fbd9 => 'Frío';

  @override
  String get s9db8aefc43 => 'Deshumidificar';

  @override
  String get s018d2e08f4 => 'Ventilador';

  @override
  String get s36fb6ba26f => 'Modbus TCP';

  @override
  String get sa70cc38354 => 'Host';

  @override
  String get sdc5301b750 => 'Unidad id';

  @override
  String get s15e327bf8e => 'Timeout (ms)';

  @override
  String get s943b8b6bf3 => 'Cuadro de registro';

  @override
  String get sf51ad986eb => 'Address (0-based)';

  @override
  String get s601f118ac0 => 'Tipo de datos';

  @override
  String get sddd62d21b0 => 'Cierre de palabras (CDAB)';

  @override
  String get see24ec5d84 => 'Escala';

  @override
  String get s0a239b832b => 'Offset';

  @override
  String get s5f374d3643 => 'Unidad id (vacío = conexión)';

  @override
  String get sef11962984 => 'Escribe';

  @override
  String get s779b59ba4b => 'Valor ({\'{value}\'} = slider/toggle)';

  @override
  String get sefaea1b818 => 'ntfy (canal de mensajería / comandos)';

  @override
  String get s6a4516e0fe => 'Tema de comando (nombre o URL completa)';

  @override
  String get se003ecc10b =>
      'Topic the commands are sent to. Usted puede pegar la URL completa, por ejemplo https://ntfy.sh/my-topic – el mismo que su iPhone Shortcut utiliza. El nombre del tema funciona como una contraseña: mantenerlo largo y aleatorio.';

  @override
  String get s800cd08229 => 'Tema de respuesta (opcional)';

  @override
  String get s2e3a66d384 =>
      'Si el dispositivo de inicio responde a otro tema, escríbelo aquí. Deja vacío si la respuesta viene sobre el mismo tema – nuestro propio comando es ignorado y el siguiente mensaje se muestra como la respuesta.';

  @override
  String get s5bc736c04a => 'Acceso a la ficha (opcional)';

  @override
  String get s77feae14f5 =>
      'Sólo se necesita para un tema protegido (cuenta n ostensible → Acceso fichas). Dejar vacío para un tema público.';

  @override
  String get seca0d75969 =>
      'Default es el público ntfy.sh. Cambiar sólo para su propio servidor ntfy. Una URL completa sobresigue esto.';

  @override
  String get sddbea594a4 =>
      'último = el mensaje más reciente, log = varios mensajes recientes (no menor primero).';

  @override
  String get s2bd0e69d44 => 'Tema (opcional)';

  @override
  String get s4eb1e8ac15 =>
      'Tema a leer. Vacío = el tema de respuesta de la conexión (o el tema de comando).';

  @override
  String get s09fa5c0332 => 'Número de mensajes (log)';

  @override
  String get s17fda9fb06 => 'Cuántos mensajes recientes muestra el registro.';

  @override
  String get s78f2f0d783 => '¿Qué tan lejos?';

  @override
  String get s79bdbfd820 =>
      'Por ejemplo 30m, 12h o 2d. El público ntfy.sh mantiene mensajes durante aproximadamente 12 horas.';

  @override
  String get sfe357edcec => 'Comando (texto para enviar)';

  @override
  String get s48e102023d =>
      'El texto para enviar, por ejemplo, \"actualizar\". Con un PIN se adjunta después de un espacio: \"actualizar 1234\".';

  @override
  String get saf2ebedf61 => 'Solicitar un PIN en prensa';

  @override
  String get sfcb5608064 =>
      'Pide un PIN (hidden) en cada prensa y lo anexa al comando. El PIN no se almacena a menos que elija \"Recordar en este dispositivo\".';

  @override
  String get sfee393b70e => 'Esperar la respuesta';

  @override
  String get sfff5bc52e5 =>
      'Escucha la respuesta del dispositivo de inicio y lo muestra en esta ficha (y como notificación cuando la aplicación está en el fondo).';

  @override
  String get sbdcbe301b9 => 'Esperar respuesta (s)';

  @override
  String get s121542d6d7 =>
      'Cuánto tiempo para esperar antes de decir que no hubo respuesta.';

  @override
  String get sa53638cfea => 'Responder permanece en la baldosa (s)';

  @override
  String get se6d21484a8 =>
      'Cuanto tiempo la respuesta se mantiene en la baldosa. 0 = hasta la siguiente prensa.';

  @override
  String get s74d68a98d6 => 'Título del mensaje (opcional)';

  @override
  String get sc2492ac3ab => 'Nombre del mensaje, por lo general vacío.';

  @override
  String s54ea45f27f(String p0, String p1) {
    return 'ntfy: tema \"$p0\" está protegido (HTTP $p1). Añadir un acceso token (tk_...) a la conexión.';
  }

  @override
  String get s72c37e530d =>
      'ntfy: demasiados mensajes (HTTP 429). Espera un momento y prueba de nuevo.';

  @override
  String get s0870daf796 => 'ntfy: tema de comando desaparecido';

  @override
  String get s28dc7ea012 => 'ntfy: conexión cerrada antes de la respuesta';

  @override
  String sa4313864fe(String p0, String p1) {
    return 'El comando fue enviado, pero ninguna respuesta llegó dentro $p0 s. Chequea que el dispositivo de casa está encendido y escucha \"$p1\".';
  }

  @override
  String get s85a1947a44 => '(sin mensajes)';

  @override
  String get s7069b18b7d => 'ntfy: texto de comando desaparecido';

  @override
  String s43de3fd299(String p0) {
    return ' Responder tema: $p0.';
  }

  @override
  String s9ed9eb7f92(String p0, String p1, String p2, String p3) {
    return '✓ ntfy server $p0 contestado y el tema \"$p1\" es legible ($p2 mensajes en la última hora).$p3 No se envió ningún comando – toque la ficha para probar.';
  }

  @override
  String get sf0ef0140c3 => 'Home Assistant';

  @override
  String get s1f90ee6992 => 'Token de acceso de larga duración';

  @override
  String get sccb0cca8e3 => 'Actualizaciones en vivo (websocket)';

  @override
  String get s8f8e1cfad3 => 'Entity id';

  @override
  String get s382111aebc => 'Atributo (vacío = estado)';

  @override
  String get sf500d0ad67 => 'Servicio';

  @override
  String get s7286715019 => 'Datos adicionales JSON ({\'{value}\'} = valor)';

  @override
  String get s1b5b0421c0 => 'La carga es hex';

  @override
  String get s44ab1d33df => 'Esperar la respuesta';

  @override
  String get s341bf61e36 => 'Respuesta como hex';

  @override
  String get se7cff2d61e => 'TCP (vacío)';

  @override
  String get s1dfeacd9f6 => 'UDP';

  @override
  String get s804e935440 => 'Cámara ESP32';

  @override
  String get s478ddb6e1a => 'Unidad de ventilación (Modbus)';

  @override
  String get s4b4fd14aaf => 'Patio';

  @override
  String get s8d06ee5308 => 'Alarma';

  @override
  String get s8ac16d45bc => '';

  @override
  String get sbde42d83a3 => 'Luces del salón';

  @override
  String get sb7c78c63b3 => 'Aire de impulsión';

  @override
  String get sbb2adef009 => 'Velocidad del ventilador';

  @override
  String get see46441329 => '0=Off;1=Away;2=Home;3=Boost;4=Max';

  @override
  String get sb25aad3bc2 => 'Salgo de casa';

  @override
  String get s7e461faf91 =>
      'Encuéntrelo en la lista de dispositivos del router o en la aplicación del dispositivo. También puede pulsar \"Búsqueda de red\".';

  @override
  String get saf4b222a68 => 'Dirección IP del dispositivo';

  @override
  String get s1bbea216af => 'Cámara ESP32-CAM';

  @override
  String get saaaeccd0cc =>
      'Cámara Wi-Fi de bajo costo. Muestra vídeo en vivo.';

  @override
  String get saaea39b2de => 'Dirección IP de cámara';

  @override
  String get s6ef2a3f197 =>
      'Se muestra en el monitor de serie en el arranque o en la lista de dispositivos del router.';

  @override
  String get sae199413a2 => 'Por ejemplo, Yard, Hallway.';

  @override
  String get s2dd165b39f => 'Tipo de imagen';

  @override
  String get sb66b153f36 =>
      'mjpeg = video en vivo (recomendado). snapshot = imagen todavía cada pocos segundos.';

  @override
  String get sf81257929d => 'Relé / enchufe Shelly';

  @override
  String get s2b8ab6defc =>
      'Cambiar una luz o un dispositivo encendido / apagado y mostrar potencia.';

  @override
  String get s7fcea114f0 => '¿Qué controla?';

  @override
  String get sdccd6e7f24 => 'Modelo';

  @override
  String get s864ba0233b =>
      'Más reciente (Plus, Pro, Gen3) = Plus / Pro / Gen2+. Old Shelly 1, 2.5, Plug S = Gen1.';

  @override
  String get s92f97cd95e => 'Mostrar potencia (W)';

  @override
  String get s54c71d86aa =>
      'Sólo para modelos con medición (por ejemplo, más 1PM).';

  @override
  String get s49671fc56f => 'Canal';

  @override
  String get s06f8a27d8a => 'Para dispositivos multicanal: 0 = primero.';

  @override
  String get s259e46c59a => 'Sólo si estableces una contraseña.';

  @override
  String get s702ca14235 => 'Dispositivo Tasmota';

  @override
  String get sc130e073ba => 'Relé o plug running Tasmota firmware.';

  @override
  String get s16be1831d6 => 'Sólo para dispositivos con medición de energía.';

  @override
  String get s8890d26ef2 => 'Número de relé';

  @override
  String get s7e6d21d466 => 'Para dispositivos multirrelés 1, 2, 3...';

  @override
  String get s5f1e4a036e => 'Contraseña web';

  @override
  String get s397e83233d =>
      'Sólo si se establece una contraseña web (usuario admin).';

  @override
  String get se0e5f715ad => 'ESPHome device';

  @override
  String get sa0efcdf688 =>
      'Su propio ESP32/ESP8266 con ESPHome (web_server habilitado).';

  @override
  String get s631420589f => 'Nombre del dispositivo';

  @override
  String get s1db899640b => 'Interruptor id (opcional)';

  @override
  String get sb2e87033fc =>
      'El nombre del interruptor de YAML en el caso inferior con subrayados.';

  @override
  String get s978ae8f1d6 => 'Sensor id (opcional)';

  @override
  String get s4ba12c5866 =>
      'Nombre del sensor de la misma manera (ver la página web del dispositivo).';

  @override
  String get s945273ef29 => 'Unidad de sensor';

  @override
  String get s5ca2e25792 => 'Sólo si web_server auth se establece.';

  @override
  String get sb847f22473 => 'Nombre de usuario web';

  @override
  String get s7f8e45ea74 =>
      'Luces, alarma, sensores, cualquier cosa en Home Assistant.';

  @override
  String get s9f70681d3f => 'Home Assistant address';

  @override
  String get s123502628e => 'La dirección con la que abres Home Assistant.';

  @override
  String get s92e3c4cd40 => 'Token de larga vida';

  @override
  String get s4e3f2052b2 =>
      'Home Assistant → su perfil → Seguridad → Tokens de acceso a larga vida → Crear token. Pruébalo aquí.';

  @override
  String get s75a056cf4d => 'Luz (opcional)';

  @override
  String get sdb9a90cb96 => 'Entidad id de Ajustes → Dispositivos → Entidades.';

  @override
  String get sa9681c1a9a => 'Alarma (opcional)';

  @override
  String get s64bd3ab3ff => 'Sensor de temperatura (opcional)';

  @override
  String get sa6504f5712 => 'Interruptor (opcional)';

  @override
  String get s64d4364336 =>
      'disarmed=Off;armed_away=Armed;armed_home=Home;armed_night=Night;triggered=ALARM;arming=Arming';

  @override
  String get s54e063bd9c => 'Bomba de calor (Auxiliar)';

  @override
  String get s2afe650320 =>
      'Bomba de calor de aire mostrada en Home Assistant como entidad climática.';

  @override
  String get s48fdd98530 =>
      'Si ya se ha añadido, se reutiliza la misma conexión.';

  @override
  String get sfe5ad3202f => 'No es necesario si HA ya está añadido.';

  @override
  String get sce069d8d1a => 'Entidad de bomba de calor';

  @override
  String get s05e2aaa15c => 'Empieza con el clima.';

  @override
  String get sc7d02fbe84 => 'Bomba de calor';

  @override
  String get se699281c85 => 'Bomba de calor (MQTT)';

  @override
  String get s8643040b95 =>
      'Por ejemplo, mitsubishi2mqtt o controlador ESP similar. Los temas son ejemplos – verificar.';

  @override
  String get s2a1148ee77 => 'Interventor MQTT IP';

  @override
  String get s53e472c976 =>
      'Máquina de correr Mosquitto (a menudo la caja HA).';

  @override
  String get s29aff3d2a0 => 'MQTT nombre de usuario';

  @override
  String get s37e57de4b9 => 'Deja vacío si no es necesario.';

  @override
  String get sffe00ea1b3 => 'Contraseña MQTT';

  @override
  String get s407d4a5e56 => 'Tema básico';

  @override
  String get sc1af622c0a =>
      'Desde la configuración del controlador. Estado: ierebase confianza/state, comandos: ■base confianza/set.';

  @override
  String get s9783a8fd53 => 'habitación';

  @override
  String get sbc996a7d25 => 'consigna';

  @override
  String get sa69c0e1ca3 => 'Bomba de calor aire (IR)';

  @override
  String get s025e7bf04d =>
      'Controle cualquier bomba de calor controlada por control remoto con un volador IR (Tasmota o ESPHome). IR es de una sola dirección: Molaplan muestra lo que envió por última vez.';

  @override
  String get sb5d4127728 => 'IR blaster';

  @override
  String get sc899cf95db =>
      'Los voladores IR más listos funcionan con Tasmota (utiliza la construcción de tasmota-ir). ESPHome = tu dispositivo ESPHome con climate_ir.';

  @override
  String get sc096a735fd =>
      'IP del transmisor IR. Para MQTT, la dirección del corredor.';

  @override
  String get safc7f1325c => 'Marca de la bomba de calor';

  @override
  String get s7675ec1754 =>
      'Escoja la marca de la unidad o remota. Si no reacciona, pruebe \"Otro\" con un protocolo alternativo.';

  @override
  String get s9702830f91 => 'Protocolo (sólo \"otro\")';

  @override
  String get s6df0837908 =>
      'Tasmota IRhvac nombre del vendedor. Sólo se necesita para \"Otros\" o para probar otro.';

  @override
  String get saa49bfdb90 => 'Se muestran en títulos de baldosas.';

  @override
  String get sf1971ac29b => 'Tema de Tasmota (sólo MQTT)';

  @override
  String get s65529d5877 =>
      'Tasmota → Configuración → MQTT → Tema. Otro blaster MQTT: tema de comandos.';

  @override
  String get s321c1677e2 => 'ESPHome climate id (ESPHome only)';

  @override
  String get s4c07dec7b5 =>
      'El objeto climate_ir id, mostrado en la página web del dispositivo.';

  @override
  String get s2229e548f3 => 'MQTT o usuario web.';

  @override
  String get s06cff48000 => 'URL de comando (otro HTTP solamente)';

  @override
  String get s5b41e244d6 =>
      'Placeholders: {\'{power}\'} {\'{mode}\'} {\'{temp}\'} {\'{fan}\'} {\'{swing}\'} {\'{vendor}\'} {\'{json}\'}.';

  @override
  String get s9a60c2026e => 'Botones de modo';

  @override
  String get sd119ce3382 =>
      'Botones para calor, fresco, auto, seco y ventilador.';

  @override
  String get s9b8dd7076a => 'Velocidad del ventilador';

  @override
  String get s9597aa1ae9 => 'Slider 0–5 (0 = auto).';

  @override
  String get secae50c5dd => 'Oscilación';

  @override
  String get s8bcb8433f9 => 'El swing de Louver en/off.';

  @override
  String get s78a5e5fa61 =>
      'Temperatura de la habitación del sensor de la explosión';

  @override
  String get s2dd6395602 =>
      'Sólo si el blaster tiene un sensor de temperatura.';

  @override
  String get s4ff78f06ab =>
      'Bomba de calor de aire (porto de servicio / ESPHome)';

  @override
  String get s6cc7b6b499 =>
      'Controlador ESPHome en el puerto de servicio de unidad interior (Mitsubishi CN105, Daikin S21/X50A, Panasonic CN-CNT, Toshiba). Dos vías: estado real y temperatura ambiente.';

  @override
  String get s647e86e5e5 => 'Climate id';

  @override
  String get sbeb6af1e1c =>
      'La entidad climática del dispositivo ESPHome. \"Encuentra bombas de calor\" en la guía lo encuentra para ti.';

  @override
  String get sbf36d139cb => 'Sólo si web_server tiene auth.';

  @override
  String get s54d4fdbba4 => 'Sólo si web_server tiene auth.';

  @override
  String get s84cd6a5180 => 'Mando RF433 (Athom IR & RF)';

  @override
  String get s4105198757 =>
      'Controlar dispositivos RF433 de radio-remote (sockets, toldos, puertas de garaje) con el Athom \"Tasmota IR & RF433 Controller\". Enseña los botones justo después de añadir.';

  @override
  String get sbc2bf08889 => 'IP del controlador Athom.';

  @override
  String get sc34430eec0 => 'Por ejemplo, lo que controlas.';

  @override
  String get s12447972e0 =>
      'Sólo si se establece una contraseña web de Tasmota.';

  @override
  String get s6385f1487e => 'Precio de la electricidad (spot)';

  @override
  String get se807a72c0a =>
      'Hoy y mañana el precio del spot como un gráfico. Control de precios: larga presión de una ficha de dispositivo → Control de precios.';

  @override
  String get sef8d24c969 => 'País / zona de precio';

  @override
  String get sef4f509f9f => 'Escoja su país; en Suecia y Noruega su área.';

  @override
  String get sf3a8631d14 => 'De su factura incl. IVA. 0 = energía solamente.';

  @override
  String get sf3be8aac1c => 'Su margen de contrato sin IVA.';

  @override
  String s49dfca65a3(String p0) {
    return 'Precio de electricidad $p0';
  }

  @override
  String get scf849c933b => 'Electricidad ahora';

  @override
  String get s53a951507b => 'Hora más barata';

  @override
  String get s3e99310fc0 => 'Precio hoy y mañana';

  @override
  String get s9af9526395 => 'Unidad de ventilación (Modbus TCP)';

  @override
  String get s29dc0baf55 =>
      'Temperaturas y velocidad de los ventiladores. Los presets de registro son ejemplos – verifique con su manual.';

  @override
  String get sb75966bb58 => 'Unidad o puerta de entrada IP';

  @override
  String get s751331a84a =>
      'Si la unidad tiene sólo RS485, necesita una puerta RS485 → Modbus TCP. Ingrese su IP.';

  @override
  String get s658cdb6ff8 => 'Marca';

  @override
  String get s785c0c264c =>
      'Escoja una marca para prefijar registros como ejemplo. \"—\" = vacío.';

  @override
  String get s7e9c785c20 => 'A menudo 1.';

  @override
  String get s0591744c19 => 'Casi siempre 502.';

  @override
  String get s5ccb7405cf => 'Ventilación';

  @override
  String get se7dfa3594e => 'Dispositivo MQTT';

  @override
  String get s12ab103795 =>
      'Cualquier dispositivo que hable MQTT (Zigbee2MQTT, su propio ESP, ...).';

  @override
  String get sffcfefd91c => 'Máquina que dirige el corredor de MQTT.';

  @override
  String get s6ac05d979c => '¿Qué es?';

  @override
  String get s460d48d0cc =>
      'interruptor = encendido / apagado, sensor = muestra un valor.';

  @override
  String get s850c7e1194 => 'Tema de estado';

  @override
  String get s49b7311a1e => 'Tema donde el dispositivo reporta su estado.';

  @override
  String get s579969e7e4 => 'Tema del comando (switch)';

  @override
  String get s137db4076a => 'Tema para el comando on/off.';

  @override
  String get s4c95226869 => 'Mensaje';

  @override
  String get s70f2ea8532 => 'Mensaje apagado';

  @override
  String get sdc234849ac => 'Campo JSON';

  @override
  String get sd3f60d4a71 => 'Si el mensaje es JSON, el nombre del campo.';

  @override
  String get s6cee917658 => 'Unidad (sensor)';

  @override
  String get s3cd541d271 => 'Otro dispositivo Wi-Fi (HTTP)';

  @override
  String get s69885630aa =>
      'Un dispositivo con una API web. Muestra un valor; añade más fichas más tarde.';

  @override
  String get s200320e245 => 'Ruta de estado';

  @override
  String get sc5872d2e30 =>
      'Donde el dispositivo reporta su estado. Vacío = ninguna baldosa ahora.';

  @override
  String get s5564de12b2 => 'Campo para mostrar';

  @override
  String get s377942beb7 => 'Nombre de campo en la respuesta.';

  @override
  String get sbaf1a279c2 => 'Comando y respuesta';

  @override
  String get se0fb2c7eea =>
      'Envíe un comando como un mensaje ntfy (por ejemplo \"actualizar\" + PIN) y vea la respuesta del dispositivo en el mismo nivel. El mismo canal que un acceso directo al iPhone.';

  @override
  String get s8231329360 => 'Tema de comando URL';

  @override
  String get sd82d127f05 =>
      'Pruebe la misma URL que sus mensajes de acceso directo se ordenan (p. ej. https://ntfy.sh/kv-cmd-...).';

  @override
  String get s1b3bbae234 =>
      'Sólo si el dispositivo de casa responde sobre otro tema. Vacío = mismo tema, nuestro propio comando es ignorado.';

  @override
  String get s1b08aa4646 =>
      'Texto mostrado en la baldosa, por ejemplo \"Actualizar\" o \"Estatus\".';

  @override
  String get s5bed8bff00 => 'Comando';

  @override
  String get se2a81ae67d =>
      'El texto a enviar. El PIN se adjunta después de un espacio, por ejemplo \"actualizar 1234\".';

  @override
  String get s1477964f04 => 'Preguntar por el PIN en cada prensa';

  @override
  String get s62672283f6 =>
      'El PIN se le pide oculto y no se almacena a menos que elija \"Recuerde en este dispositivo\".';

  @override
  String get sb5e914eaf7 =>
      'Sólo para un tema protegido. Dejar vacío para un tema público.';

  @override
  String get s1a98a7e424 => 'También agregue una ficha de registro de mensajes';

  @override
  String get s5ab6348524 =>
      'Muestra los mensajes más recientes del tema en su propia ficha.';

  @override
  String get s57e684ac9e => 'Mensajes';

  @override
  String get sdc84bf286f =>
      'off=Off;heat=Heat;cool=Cool;auto=Auto;heat_cool=Auto;dry=Dry;fan_only=Fan';

  @override
  String s3378eb2d0b(String p0) {
    return '$p0 – temperature';
  }

  @override
  String get saa437260b8 => 'Estado enviado (IR es de una sola dirección)';

  @override
  String get sfffb54daf4 => 'Estado';

  @override
  String get seab2c72485 => 'Fan (0 = auto)';

  @override
  String get sfb0b971c01 => 'Oscilación';

  @override
  String s3a38b97f7b(String p0) {
    return '$p0 – room';
  }
}
