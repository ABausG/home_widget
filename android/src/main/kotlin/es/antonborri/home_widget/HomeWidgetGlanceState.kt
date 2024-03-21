import android.content.Context
import android.content.SharedPreferences
import android.os.Environment
import androidx.datastore.core.DataStore
import androidx.glance.state.GlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetPlugin
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import java.io.File

class HomeWidgetGlanceState(val preferences: SharedPreferences)

class HomeWidgetGlanceStateDefinition : GlanceStateDefinition<HomeWidgetGlanceState> {
    override suspend fun getDataStore(context: Context, fileKey: String): DataStore<HomeWidgetGlanceState> {
        val preferences = context.getSharedPreferences(HomeWidgetPlugin.PREFERENCES, Context.MODE_PRIVATE)
        return HomeWidgetGlanceDataStore(preferences)
    }

    override fun getLocation(context: Context, fileKey: String): File {
        return Environment.getDataDirectory()
    }

}

private class HomeWidgetGlanceDataStore(private val preferences: SharedPreferences) : DataStore<HomeWidgetGlanceState> {
    override val data: Flow<HomeWidgetGlanceState>
        get() = flow { emit(HomeWidgetGlanceState(preferences)) }

    override suspend fun updateData(transform: suspend (t: HomeWidgetGlanceState) -> HomeWidgetGlanceState): HomeWidgetGlanceState {
        return transform(HomeWidgetGlanceState(preferences))
    }
}