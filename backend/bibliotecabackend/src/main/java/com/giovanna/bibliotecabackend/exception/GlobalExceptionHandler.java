package com.giovanna.bibliotecabackend.exception;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.LinkedHashMap;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<Map<String, String>> handleDataIntegrityViolation(
            DataIntegrityViolationException ex
    ) {
        return buildResponse(HttpStatus.BAD_REQUEST, ex);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, String>> handleGenericException(Exception ex) {
        return buildResponse(HttpStatus.INTERNAL_SERVER_ERROR, ex);
    }

    private ResponseEntity<Map<String, String>> buildResponse(HttpStatus status, Exception ex) {
        Map<String, String> body = new LinkedHashMap<>();
        body.put("error", status.getReasonPhrase());
        body.put("message", extractMessage(ex));
        body.put("exception", ex.getClass().getSimpleName());
        return ResponseEntity.status(status).body(body);
    }

    private String extractMessage(Exception ex) {
        if (ex.getCause() != null && ex.getCause().getMessage() != null) {
            return ex.getCause().getMessage();
        }
        if (ex.getMessage() != null) {
            return ex.getMessage();
        }
        return "Erro interno sem detalhes";
    }
}
