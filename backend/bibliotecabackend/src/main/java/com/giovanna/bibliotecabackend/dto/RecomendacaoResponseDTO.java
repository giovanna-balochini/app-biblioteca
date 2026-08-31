package com.giovanna.bibliotecabackend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.ArrayList;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RecomendacaoResponseDTO {

    private Long livroId;
    private Long idProprietarioOriginal;
    private String titulo;
    private String autor;
    private String genero;
    private String editora;
    private String imagem;
    private String descricao;

    private int matchPercentual;
    @Builder.Default
    private List<String> motivos = new ArrayList<>();
    private Double notaMedia;
    private Long quantidadeAvaliacoes;
}
