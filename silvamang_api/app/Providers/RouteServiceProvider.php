<?php

namespace App\Providers;

use App\Models\Alert;
use App\Models\AiModel;
use App\Models\AssistantLog;
use App\Models\LocationValidation;
use App\Models\Measurement;
use App\Models\Prediction;
use App\Models\ScanImage;
use App\Models\ScanRecord;
use App\Support\ApiId;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Foundation\Support\Providers\RouteServiceProvider as ServiceProvider;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Route;
use InvalidArgumentException;

class RouteServiceProvider extends ServiceProvider
{
    /**
     * The path to your application's "home" route.
     *
     * Typically, users are redirected here after authentication.
     *
     * @var string
     */
    public const HOME = '/admin/dashboard';

    /**
     * Define your route model bindings, pattern filters, and other route configuration.
     */
    public function boot(): void
    {
        $this->bindProtectedApiIds();

        RateLimiter::for('api', function (Request $request) {
            return Limit::perMinute(60)->by($request->user()?->id ?: $request->ip());
        });

        $this->routes(function () {
            Route::middleware('api')
                ->prefix('api')
                ->group(base_path('routes/api.php'));

            Route::middleware('web')
                ->group(base_path('routes/web.php'));
        });
    }

    private function bindProtectedApiIds(): void
    {
        $bindings = [
            'assistantLog' => AssistantLog::class,
            'assistant_log' => AssistantLog::class,
            'aiModel' => AiModel::class,
            'ai_model' => AiModel::class,
            'alert' => Alert::class,
            'locationValidation' => LocationValidation::class,
            'location_validation' => LocationValidation::class,
            'measurement' => Measurement::class,
            'prediction' => Prediction::class,
            'scanImage' => ScanImage::class,
            'scan_image' => ScanImage::class,
            'scanRecord' => ScanRecord::class,
            'scan_record' => ScanRecord::class,
        ];

        foreach ($bindings as $parameter => $modelClass) {
            Route::bind($parameter, fn (mixed $value) => $this->resolveProtectedApiModel($modelClass, $value));
        }
    }

    /**
     * @param  class-string<\Illuminate\Database\Eloquent\Model>  $modelClass
     */
    private function resolveProtectedApiModel(string $modelClass, mixed $value): object
    {
        try {
            $id = ApiId::decodeOrFail($value, allowPlainNumeric: ! request()->is('api/*'));
        } catch (InvalidArgumentException) {
            throw (new ModelNotFoundException())->setModel($modelClass, [$value]);
        }

        $model = $modelClass::query()->find($id);

        if (! $model) {
            throw (new ModelNotFoundException())->setModel($modelClass, [$value]);
        }

        return $model;
    }
}
