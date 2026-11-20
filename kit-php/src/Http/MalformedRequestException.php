<?php

declare(strict_types=1);

namespace TodoApp\Http;

use RuntimeException;

/** Corps de requête illisible ou hors contrat → HTTP 400. */
final class MalformedRequestException extends RuntimeException
{
}
