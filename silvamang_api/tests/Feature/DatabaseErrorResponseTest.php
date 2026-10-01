<?php

namespace Tests\Feature;

use App\Exceptions\Handler;
use Illuminate\Database\QueryException;
use Illuminate\Http\Request;
use PDOException;
use Tests\TestCase;

class DatabaseErrorResponseTest extends TestCase
{
    public function test_query_errors_do_not_claim_a_connection_failure_or_expose_sql(): void
    {
        foreach (["Table 'users' doesn't exist", 'Connection refused', 'Duplicate entry'] as $cause) {
            $exception = new QueryException('mysql', 'select * from users where email = ?',
                ['private@example.test'], new PDOException($cause));
            $request = Request::create('/api/register', 'POST');
            $request->headers->set('Accept', 'application/json');
            $response = $this->app->make(Handler::class)->render($request, $exception);

            $this->assertSame(500, $response->getStatusCode());
            $this->assertSame([
                'message' => 'The server could not complete your request. Please try again later or contact support.',
            ], json_decode($response->getContent(), true));
        }
    }
}
