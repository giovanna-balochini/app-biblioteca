package com.giovanna.bibliotecabackend.dto;

import lombok.Data;

@Data
public class RegistroRequest {
    private String nome;
    private String email;
    private String senha;
}
