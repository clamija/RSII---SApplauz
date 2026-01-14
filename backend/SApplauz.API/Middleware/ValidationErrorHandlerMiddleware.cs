using FluentValidation;
using System.Net;
using System.Text.Json;

namespace SApplauz.API.Middleware;

public class ValidationErrorHandlerMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ValidationErrorHandlerMiddleware> _logger;

    public ValidationErrorHandlerMiddleware(RequestDelegate next, ILogger<ValidationErrorHandlerMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (ValidationException ex)
        {
            await HandleValidationExceptionAsync(context, ex);
        }
    }

    private static Task HandleValidationExceptionAsync(HttpContext context, ValidationException ex)
    {
        context.Response.ContentType = "application/json";
        context.Response.StatusCode = (int)HttpStatusCode.BadRequest;

        var errors = ex.Errors
            .GroupBy(e => e.PropertyName)
            .ToDictionary(
                g => g.Key,
                g => g.Select(e => e.ErrorMessage).ToArray()
            );

        // Formatiraj poruke u specifičan format
        var errorMessages = ex.Errors.Select(e => e.ErrorMessage).ToList();
        
        var response = new
        {
            message = errorMessages.Count == 1 
                ? errorMessages.First() 
                : "Postoje greške u validaciji podataka.",
            errors = errors,
            details = errorMessages
        };

        var jsonResponse = JsonSerializer.Serialize(response, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        return context.Response.WriteAsync(jsonResponse);
    }
}
