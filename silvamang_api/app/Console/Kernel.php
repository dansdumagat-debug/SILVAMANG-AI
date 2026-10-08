<?php

namespace App\Console;

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;

class Kernel extends ConsoleKernel
{
    /**
     * Define the application's command schedule.
     */
    protected function schedule(Schedule $schedule): void
    {
        // $schedule->command('inspire')->hourly();
    }

    /**
     * Register the commands for the application.
     */
    protected function commands(): void
    {
        // Also support containers whose optimized class map predates this command.
        require_once __DIR__.'/Commands/PrepareTrainingSnapshot.php';
        $this->load(__DIR__.'/Commands');

        require base_path('routes/console.php');
    }
}
