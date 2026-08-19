package com.giovanna.bibliotecabackend.dto;

import com.giovanna.bibliotecabackend.model.Avaliacao;
import lombok.Data;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
public class AvaliacaoPublicaDTO {
    private Long id;
    private Long usuarioId;
    private String usuarioNome;
    private String usuarioFotoPerfil;
    private Long livroId;
    private String livroTitulo;
    private String livroAutor;
    private String livroGenero;
    private String livroCapa;
    private Integer nota;
    private String comentario;
    private LocalDate dataConclusao;
    private LocalDateTime dataCriacao;
    private LocalDateTime dataAtualizacao;

    public static AvaliacaoPublicaDTO fromEntity(Avaliacao a) {
        AvaliacaoPublicaDTO dto = new AvaliacaoPublicaDTO();
        dto.setId(a.getId());
        dto.setNota(a.getNota());
        dto.setComentario(a.getComentario());
        dto.setDataConclusao(a.getDataConclusao());
        dto.setDataCriacao(a.getDataCriacao());
        dto.setDataAtualizacao(a.getDataAtualizacao());
        if (a.getLivro() != null) {
            dto.setLivroId(a.getLivro().getId());
            dto.setLivroTitulo(a.getLivro().getTitulo());
            dto.setLivroAutor(a.getLivro().getAutor());
            dto.setLivroGenero(a.getLivro().getGenero());
            dto.setLivroCapa(a.getLivro().getImagem());
        }
        if (a.getAutor() != null) {
            dto.setUsuarioId(a.getAutor().getId());
            dto.setUsuarioNome(a.getAutor().getNome());
            dto.setUsuarioFotoPerfil(a.getAutor().getFotoPerfil());
        }
        return dto;
    }
}
