package com.giovanna.bibliotecabackend.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class AuthResponse {
    private String token;
    private String tipo = "Bearer";
    private Long usuarioId;
    private String email;
    private String nome;

    public AuthResponse(String token, Long usuarioId, String email, String nome) {
        this.token = token;
        this.usuarioId = usuarioId;
        this.email = email;
        this.nome = nome;
    }
}
