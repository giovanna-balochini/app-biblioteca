package com.giovanna.bibliotecabackend.dto;

import com.giovanna.bibliotecabackend.model.Livro;
import com.giovanna.bibliotecabackend.model.StatusLeitura;
import lombok.Data;

import java.time.LocalDate;

@Data
public class LivroBuscaDTO {
    private Long id;
    private String titulo;
    private String autor;
    private String editora;
    private String genero;
    private String descricao;
    private String imagem;
    private boolean lido;
    private String statusLeitura;
    private Integer paginaAtual;
    private Integer totalPaginas;
    private double progressoPercentual;
    private LocalDate dataInicioLeitura;
    private LocalDate dataFimLeitura;
    private Long donoId;
    private String donoNome;
    private String donoFotoPerfil;
    private long totalAvaliacoesPublicas;
    private Double mediaAvaliacoes;
    private boolean estaNaMinhaBiblioteca;

    public static LivroBuscaDTO fromEntity(
            Livro l,
            long totalAvaliacoesPublicas,
            Double mediaAvaliacoes,
            boolean estaNaMinhaBiblioteca
    ) {
        LivroBuscaDTO dto = new LivroBuscaDTO();
        dto.setId(l.getId());
        dto.setTitulo(l.getTitulo());
        dto.setAutor(l.getAutor());
        dto.setEditora(l.getEditora());
        dto.setGenero(l.getGenero());
        dto.setDescricao(l.getDescricao());
        dto.setImagem(l.getImagem());
        dto.setLido(l.isLido());
        dto.setStatusLeitura((l.getStatusLeitura() == null ? StatusLeitura.QUERO_LER : l.getStatusLeitura()).name());
        dto.setPaginaAtual(l.getPaginaAtual());
        dto.setTotalPaginas(l.getTotalPaginas());
        dto.setProgressoPercentual(l.getProgressoPercentual());
        dto.setDataInicioLeitura(l.getDataInicioLeitura());
        dto.setDataFimLeitura(l.getDataFimLeitura());
        if (l.getDono() != null) {
            dto.setDonoId(l.getDono().getId());
            dto.setDonoNome(l.getDono().getNome());
            dto.setDonoFotoPerfil(l.getDono().getFotoPerfil());
        }
        dto.setTotalAvaliacoesPublicas(totalAvaliacoesPublicas);
        dto.setMediaAvaliacoes(mediaAvaliacoes == null ? null : Math.round(mediaAvaliacoes * 10.0) / 10.0);
        dto.setEstaNaMinhaBiblioteca(estaNaMinhaBiblioteca);
        return dto;
    }
}
