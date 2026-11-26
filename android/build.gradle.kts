allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// flutter_blue_plus 1.34.x (newest that resolves with wakelock_plus' dbus) still says
// compileSdkVersion 33, but its androidx dependencies need 34+. Raise it for that plugin only.
subprojects {
    if (name == "flutter_blue_plus") {
        val raise = {
            val android = extensions.findByName("android")
            android?.javaClass?.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)?.invoke(android, 36)
        }
        if (state.executed) raise() else afterEvaluate { raise() }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Release "lint vital" crashes on some plugin sources (image_picker_android, lint NoSuchMethodError
// in JavaDocParser). It only checks plugin code we do not ship changes to: skip it.
subprojects {
    tasks.configureEach {
        if (name.startsWith("lintVital")) enabled = false
    }
}
