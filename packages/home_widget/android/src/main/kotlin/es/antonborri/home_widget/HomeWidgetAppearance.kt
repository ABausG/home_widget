package es.antonborri.home_widget

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.drawable.Icon
import android.os.Build
import android.widget.RemoteViews
import androidx.annotation.RequiresApi
import androidx.glance.layout.ContentScale

/**
 * Lets a Glance widget follow the system switching between light and dark without an update.
 *
 * No broadcast reaches a widget when the night mode changes: the launcher inflates the
 * `RemoteViews` it holds again under the new configuration, so only what resolves against that
 * configuration switches. From Android 12 a `RemoteViews` carries day/night pairs of colors and
 * icons, which the launcher picks between itself. Below Android 12 a widget keeps the appearance it
 * was rendered in until it is updated.
 *
 * This exists for the widgets `home_widget generate` writes: the code calling it is generated
 * alongside it, and the composables building on it are generated into the app, which has the
 * Compose compiler this plugin does not.
 */
object HomeWidgetAppearance {
  /**
   * Whether the launcher switches the appearance of a placed widget itself: Android 12 and newer.
   */
  val switchesLive: Boolean
    get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S

  private class ConfigurationContexts(
      val configuration: Configuration,
      val contexts: DayNight<Context>,
  )

  @Volatile private var cached: ConfigurationContexts? = null

  /**
   * A context in the configuration of [context], set to the dark color scheme when [night] is true
   * and to the light one otherwise, which what is resolved for that appearance resolves its
   * resources against.
   *
   * Both are created from the application context once per configuration, not per call, so the ones
   * kept between calls never hold on to [context].
   */
  fun configurationContext(context: Context, night: Boolean): Context {
    val contexts = configurationContexts(context)
    return if (night) contexts.night else contexts.day
  }

  private fun configurationContexts(context: Context): DayNight<Context> {
    val configuration = Configuration(context.resources.configuration)
    cached?.let { if (it.configuration == configuration) return it.contexts }
    val application = context.applicationContext ?: context
    val contexts =
        DayNight(
            day = withNightMode(application, configuration, Configuration.UI_MODE_NIGHT_NO),
            night = withNightMode(application, configuration, Configuration.UI_MODE_NIGHT_YES),
        )
    cached = ConfigurationContexts(configuration, contexts)
    return contexts
  }

  private fun withNightMode(base: Context, configuration: Configuration, mode: Int): Context {
    val override = Configuration(configuration)
    override.uiMode = (override.uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or mode
    return base.createConfigurationContext(override)
  }

  /**
   * An image showing [day] in the light color scheme and [night] in the dark one, scaled the way a
   * Glance `Image` of [contentScale] scales its bitmap, and tinted by the ARGB colors of [tint] in
   * each scheme when given.
   *
   * The pair is a `RemoteViews` icon pair, which the launcher switches between itself. Its bitmaps
   * do not count towards the bitmap memory a widget may use, which only covers bitmaps set
   * directly.
   */
  @RequiresApi(Build.VERSION_CODES.S)
  fun image(
      context: Context,
      day: Bitmap,
      night: Bitmap,
      contentDescription: String?,
      contentScale: ContentScale,
      tint: DayNight<Int>? = null,
  ): RemoteViews {
    val layout =
        when (contentScale) {
          ContentScale.Crop -> R.layout.hw_appearance_image_crop
          ContentScale.FillBounds -> R.layout.hw_appearance_image_fill_bounds
          else -> R.layout.hw_appearance_image_fit
        }
    val views = RemoteViews(context.packageName, layout)
    val image = R.id.hw_appearance_image
    views.setIcon(
        image,
        "setImageIcon",
        Icon.createWithBitmap(day),
        Icon.createWithBitmap(night),
    )
    if (contentDescription != null) views.setContentDescription(image, contentDescription)
    if (tint != null) views.setColorInt(image, "setColorFilter", tint.day, tint.night)
    return views
  }

  /**
   * The values of something shown in the light ([day]) and the dark ([night]) color scheme, the
   * same value where the two cannot differ.
   */
  class DayNight<T>(val day: T, val night: T) {
    /** Both values through [transform], which runs once when they are the same. */
    fun <R> map(transform: (T) -> R): DayNight<R> {
      if (day == night) {
        val value = transform(day)
        return DayNight(value, value)
      }
      return DayNight(transform(day), transform(night))
    }
  }

  /**
   * The values shown in either color scheme, each falling back to the other one, or null when
   * neither has a value.
   *
   * Where the launcher does not switch by itself, both are the value of the appearance [context]
   * shows, and only the variants that takes are evaluated.
   */
  inline fun <T : Any> pick(context: Context, light: () -> T?, dark: () -> T?): DayNight<T>? {
    if (!switchesLive) {
      val value = (if (isNight(context)) dark() ?: light() else light() ?: dark()) ?: return null
      return DayNight(value, value)
    }
    val lightValue = light()
    val darkValue = dark()
    val day = lightValue ?: darkValue ?: return null
    return DayNight(day, darkValue ?: day)
  }

  /** Whether [context] shows the dark color scheme. */
  fun isNight(context: Context): Boolean =
      (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
          Configuration.UI_MODE_NIGHT_YES
}
