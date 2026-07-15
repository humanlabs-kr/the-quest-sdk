import com.vanniktech.maven.publish.AndroidSingleVariantLibrary
import com.vanniktech.maven.publish.SonatypeHost

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("com.vanniktech.maven.publish")
}

// gradle.properties stores the version with a release-please marker comment
// (`0.1.0 # x-release-please-version`). java.util.Properties does not treat an
// inline `#` as a comment, so strip everything after it before use.
val versionName: String =
    providers.gradleProperty("VERSION_NAME").get().substringBefore("#").trim()

android {
    namespace = "world.humanlabs.quest"
    compileSdk = 34

    defaultConfig {
        minSdk = 24
        consumerProguardFiles("consumer-rules.pro")
    }

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        buildConfigField("String", "SDK_VERSION", "\"$versionName\"")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    testOptions {
        unitTests {
            isReturnDefaultValues = true
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    // Photo Picker (PickVisualMedia) for permission-free <input type="file"> handling.
    implementation("androidx.activity:activity:1.9.3")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.4")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.13")
    testImplementation("androidx.test:core:1.6.1")
}

mavenPublishing {
    publishToMavenCentral(SonatypeHost.CENTRAL_PORTAL, automaticRelease = true)
    signAllPublications()

    coordinates(
        groupId = project.property("GROUP").toString(),
        artifactId = project.property("POM_ARTIFACT_ID").toString(),
        version = versionName,
    )

    configure(
        AndroidSingleVariantLibrary(
            variant = "release",
            sourcesJar = true,
            publishJavadocJar = true,
        )
    )

    pom {
        name.set(project.property("POM_NAME").toString())
        description.set(project.property("POM_DESCRIPTION").toString())
        inceptionYear.set(project.property("POM_INCEPTION_YEAR").toString())
        url.set(project.property("POM_URL").toString())
        licenses {
            license {
                name.set(project.property("POM_LICENSE_NAME").toString())
                url.set(project.property("POM_LICENSE_URL").toString())
                distribution.set(project.property("POM_LICENSE_DIST").toString())
            }
        }
        developers {
            developer {
                id.set(project.property("POM_DEVELOPER_ID").toString())
                name.set(project.property("POM_DEVELOPER_NAME").toString())
                url.set(project.property("POM_DEVELOPER_URL").toString())
                email.set(project.property("POM_DEVELOPER_EMAIL").toString())
            }
        }
        scm {
            url.set(project.property("POM_SCM_URL").toString())
            connection.set(project.property("POM_SCM_CONNECTION").toString())
            developerConnection.set(project.property("POM_SCM_DEV_CONNECTION").toString())
        }
    }
}
