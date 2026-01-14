allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Primijeni Groovy skriptu za JVM target fix
apply(from = "jvm_target_fix.gradle")

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build_android")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    
    // Postavi namespace i JVM target kompatibilnost za sve podprojekte
    project.afterEvaluate {
        // Postavi namespace za qr_code_scanner i druge plugine koji ga nemaju
        if (project.plugins.hasPlugin("com.android.library")) {
            val androidExtension = project.extensions.findByName("android")
            if (androidExtension != null) {
                try {
                    // Pročitaj package iz AndroidManifest.xml i postavi namespace
                    val manifestFile = project.file("src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        val manifestContent = manifestFile.readText()
                        val packageMatch = Regex("package=[\"']([^\"']+)[\"']").find(manifestContent)
                        if (packageMatch != null) {
                            val namespace = packageMatch.groupValues[1]
                            
                            // Pokušaj postaviti namespace kroz reflection
                            val setNamespaceMethod = androidExtension::class.java.methods.find { 
                                it.name == "setNamespace" && it.parameterCount == 1 
                            }
                            if (setNamespaceMethod != null) {
                                setNamespaceMethod.invoke(androidExtension, namespace)
                                println("Set namespace for ${project.name}: $namespace")
                            }
                        }
                    }
                } catch (e: Exception) {
                    // Ignoriši greške ako namespace već postoji ili nije moguće postaviti
                }
            }
        }
        
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// --- Flutter run workaround (Windows file lock) ---
// Gradle build output je preusmjeren u ../build_android (vidi iznad) da zaobiđemo locked folder.
// Flutter tool ipak očekuje APK u ../build/app/outputs/flutter-apk/app-debug.apk, pa ga kopiramo nakon assembleDebug.
val flutterExpectedOutDir = file("../build/app/outputs/flutter-apk")

val copyDebugApkToFlutterBuild = tasks.register("copyDebugApkToFlutterBuild") {
    doLast {
        val candidates = listOf(
            rootProject.layout.buildDirectory.file("app/outputs/flutter-apk/app-debug.apk").get().asFile,
            rootProject.layout.buildDirectory.file("app/outputs/apk/debug/app-debug.apk").get().asFile,
            file("${rootProject.layout.buildDirectory.asFile.get()}/app/outputs/flutter-apk/app-debug.apk"),
            file("${rootProject.layout.buildDirectory.asFile.get()}/app/outputs/apk/debug/app-debug.apk"),
        ).distinct()

        val src = candidates.firstOrNull { it.exists() }
        if (src == null) {
            println("copyDebugApkToFlutterBuild: No debug APK found to copy.")
            candidates.forEach { println("  looked in: $it") }
            return@doLast
        }

        if (!flutterExpectedOutDir.exists()) flutterExpectedOutDir.mkdirs()
        val dest = file("${flutterExpectedOutDir.path}/app-debug.apk")
        src.copyTo(dest, overwrite = true)
        println("copyDebugApkToFlutterBuild: Copied APK to ${dest.path}")
    }
}

val copyReleaseApkToFlutterBuild = tasks.register("copyReleaseApkToFlutterBuild") {
    doLast {
        val candidates = listOf(
            rootProject.layout.buildDirectory.file("app/outputs/flutter-apk/app-release.apk").get().asFile,
            rootProject.layout.buildDirectory.file("app/outputs/apk/release/app-release.apk").get().asFile,
            file("${rootProject.layout.buildDirectory.asFile.get()}/app/outputs/flutter-apk/app-release.apk"),
            file("${rootProject.layout.buildDirectory.asFile.get()}/app/outputs/apk/release/app-release.apk"),
        ).distinct()

        val src = candidates.firstOrNull { it.exists() }
        if (src == null) {
            println("copyReleaseApkToFlutterBuild: No release APK found to copy.")
            candidates.forEach { println("  looked in: $it") }
            return@doLast
        }

        if (!flutterExpectedOutDir.exists()) flutterExpectedOutDir.mkdirs()
        val dest = file("${flutterExpectedOutDir.path}/app-release.apk")
        src.copyTo(dest, overwrite = true)
        println("copyReleaseApkToFlutterBuild: Copied APK to ${dest.path}")
    }
}

// Flutter pokreće root task "assembleDebug" (ne nužno :app:assembleDebug), pa zakači finalize na sve assembleDebug taskove.
allprojects {
    tasks.matching { it.name == "assembleDebug" }.configureEach {
        finalizedBy(copyDebugApkToFlutterBuild)
    }

    tasks.matching { it.name == "assembleRelease" }.configureEach {
        finalizedBy(copyReleaseApkToFlutterBuild)
    }
}
