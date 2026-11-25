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
