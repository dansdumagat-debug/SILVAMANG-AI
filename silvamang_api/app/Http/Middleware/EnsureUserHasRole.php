<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureUserHasRole
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        if (! $request->user()) {
            return response()->json([
                'message' => 'Unauthenticated.',
            ], 401);
        }

        $roles = array_slice(func_get_args(), 2);

        if ($request->user()->hasAnyRole($roles)) {
            return $next($request);
        }

        return response()->json([
            'message' => 'You do not have permission to access this resource.',
        ], 403);
    }
}
