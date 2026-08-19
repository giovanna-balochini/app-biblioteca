package com.giovanna.bibliotecabackend.service;

import com.giovanna.bibliotecabackend.model.Avaliacao;
import com.giovanna.bibliotecabackend.model.Livro;
import com.giovanna.bibliotecabackend.model.Usuario;
import com.giovanna.bibliotecabackend.repository.AvaliacaoRepository;
import com.giovanna.bibliotecabackend.repository.LivroRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.Collections;
import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class AvaliacaoService {

    private final AvaliacaoRepository avaliacaoRepository;
    private final LivroRepository livroRepository;
    private final UsuarioService usuarioService;
    private final SeguidorService seguidorService;

    public List<Avaliacao> listarPorLivro(Long livroId) {
        Livro livro = livroRepository.findById(livroId)
                .orElseThrow(() -> new IllegalArgumentException("Livro não encontrado"));
        return avaliacaoRepository.findByLivroComAutor(livro);
    }

    public Avaliacao publicarOuAtualizar(Long livroId, Integer nota, String comentario, LocalDate dataConclusao) {
        if (nota == null || nota < 1 || nota > 5) {
            throw new IllegalArgumentException("A nota deve ser entre 1 e 5");
        }
        Usuario autor = usuarioService.obterUsuarioLogado();
        Livro livro = livroRepository.findById(livroId)
                .orElseThrow(() -> new IllegalArgumentException("Livro não encontrado"));

        Optional<Avaliacao> existente = avaliacaoRepository.findByAutorAndLivro(autor, livro);
        Avaliacao avaliacao = existente.orElseGet(Avaliacao::new);
        avaliacao.setAutor(autor);
        avaliacao.setLivro(livro);
        avaliacao.setNota(nota);
        avaliacao.setComentario(comentario);
        avaliacao.setDataConclusao(dataConclusao);
        return avaliacaoRepository.save(avaliacao);
    }

    public Double mediaPorLivro(Long livroId) {
        Livro livro = livroRepository.findById(livroId).orElse(null);
        if (livro == null) return null;
        Double media = avaliacaoRepository.calcularMediaPorLivro(livro);
        return media == null ? null : Math.round(media * 10.0) / 10.0;
    }

    public void migrarAvaliacaoLegada(Livro livro, Integer nota, String dataConclusao) {
        if (nota == null || livro.getDono() == null) return;
        if (avaliacaoRepository.existsByAutorAndLivro(livro.getDono(), livro)) return;
        try {
            Avaliacao av = new Avaliacao();
            av.setAutor(livro.getDono());
            av.setLivro(livro);
            av.setNota(nota);
            if (dataConclusao != null && !dataConclusao.isBlank()) {
                av.setDataConclusao(LocalDate.parse(dataConclusao));
            }
            avaliacaoRepository.save(av);
        } catch (Exception ignored) {}
    }

    public Page<Avaliacao> listarFeed(int pagina, int tamanho, String filtro) {
        if (pagina < 0) pagina = 0;
        if (tamanho < 1 || tamanho > 100) tamanho = 20;
        PageRequest pageRequest = PageRequest.of(pagina, tamanho, Sort.by(Sort.Direction.DESC, "dataCriacao"));

        boolean apenasSeguindo = "seguindo".equalsIgnoreCase(filtro)
                || "quem-sigo".equalsIgnoreCase(filtro)
                || "sigo".equalsIgnoreCase(filtro);

        if (apenasSeguindo) {
            List<Long> idsAutores = seguidorService.idsDosQueEuSigo();
            if (idsAutores == null || idsAutores.isEmpty()) {
                return new org.springframework.data.domain.PageImpl<>(Collections.emptyList(), pageRequest, 0);
            }
            return avaliacaoRepository.findFeedPaginadoDeAutores(idsAutores, pageRequest);
        }

        return avaliacaoRepository.findFeedPaginado(pageRequest);
    }
}
