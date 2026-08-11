package com.giovanna.bibliotecabackend.model;

import jakarta.persistence.*;
import lombok.Data;

@Data
@Entity
@Table(name = "livro")
public class Livro {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String titulo;
    private String autor;
    private String editora;
    private String genero;
    @Column(length = 500)
    private String descricao;
    private String imagem;
    private boolean lido;
    private Integer avaliacao; // 1 a 5 estrelas
    private String dataConclusao; // Formato ISO: yyyy-MM-dd (ex: 2026-08-11)
    
}
