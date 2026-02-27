# Flutter keeps.
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Stripe push provisioning optional classes referenced by transitive code paths.
# Suppress R8 missing-class failures when these artifacts are absent.
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider

# Flutter deferred-components references can appear even when Play task classes
# are not bundled; suppress warnings for non-used code paths.
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
