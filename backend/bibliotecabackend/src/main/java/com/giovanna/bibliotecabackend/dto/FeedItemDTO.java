package com.giovanna.bibliotecabackend.dto;

import com.giovanna.bibliotecabackend.model.Avaliacao;
import lombok.Data;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
public class FeedItemDTO {
    private Long idAvaliacao;
    private Integer nota;
    private String comentario;
    private LocalDate dataConclusao;
    private LocalDateTime dataPublicacao;

    private Long usuarioId;
    private String usuarioNome;
    private String usuarioFotoPerfil;

    private Long livroId;
    private String livroTitulo;
    private String livroAutor;
    private String livroGenero;
    private String livroCapa;

    public static FeedItemDTO fromEntity(Avaliacao a) {
        FeedItemDTO dto = new FeedItemDTO();
        dto.setIdAvaliacao(a.getId());
        dto.setNota(a.getNota());
        dto.setComentario(a.getComentario());
        dto.setDataConclusao(a.getDataConclusao());
        dto.setDataPublicacao(a.getDataCriacao());
        if (a.getAutor() != null) {
            dto.setUsuarioId(a.getAutor().getId());
            dto.setUsuarioNome(a.getAutor().getNome());
            dto.setUsuarioFotoPerfil(a.getAutor().getFotoPerfil());
        }
        if (a.getLivro() != null) {
            dto.setLivroId(a.getLivro().getId());
            dto.setLivroTitulo(a.getLivro().getTitulo());
            dto.setLivroAutor(a.getLivro().getAutor());
            dto.setLivroGenero(a.getLivro().getGenero());
            dto.setLivroCapa(a.getLivro().getImagem());
        }
        return dto;
    }
}
