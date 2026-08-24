package com.giovanna.bibliotecabackend.service;

import com.giovanna.bibliotecabackend.dto.AvaliacaoPublicaDTO;
import com.giovanna.bibliotecabackend.model.Avaliacao;
import com.giovanna.bibliotecabackend.model.Livro;
import com.giovanna.bibliotecabackend.model.Usuario;
import com.giovanna.bibliotecabackend.repository.AvaliacaoRepository;
import com.giovanna.bibliotecabackend.repository.LivroRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AvaliacaoService {

    private final AvaliacaoRepository avaliacaoRepository;
    private final LivroRepository livroRepository;
    private final UsuarioService usuarioService;
    private final SeguidorService seguidorService;
    private final NotificacaoService notificacaoService;
    private final CurtidaService curtidaService;

    @Transactional(readOnly = true)
    public List<AvaliacaoPublicaDTO> listarPorLivroDTO(Long livroId) {
        Livro livro = livroRepository.findById(livroId)
                .orElseThrow(() -> new IllegalArgumentException("Livro não encontrado"));
        List<Avaliacao> lista = avaliacaoRepository.findByLivroComAutor(livro);
        return aplicarCurtidasEmLote(lista);
    }

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
        boolean nova = existente.isEmpty();
        avaliacao.setAutor(autor);
        avaliacao.setLivro(livro);
        avaliacao.setNota(nota);
        avaliacao.setComentario(comentario);
        avaliacao.setDataConclusao(dataConclusao);
        Avaliacao salvo = avaliacaoRepository.save(avaliacao);
        if (nova) notificacaoService.criarNotificacaoAvaliacao(salvo);
        return salvo;
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

    @Transactional(readOnly = true)
    public Page<AvaliacaoPublicaDTO> listarFeedDTO(int pagina, int tamanho, String filtro) {
        Page<Avaliacao> page = listarFeed(pagina, tamanho, filtro);
        List<AvaliacaoPublicaDTO> dtos = aplicarCurtidasEmLote(page.getContent());
        return new PageImpl<>(dtos, page.getPageable(), page.getTotalElements());
    }

    @Transactional(readOnly = true)
    public Page<AvaliacaoPublicaDTO> listarPorAutorDTO(Long autorId, int pagina, int tamanho) {
        Usuario autor = usuarioService.buscarPorId(autorId)
                .orElseThrow(() -> new IllegalArgumentException("Usuário não encontrado"));
        if (pagina < 0) pagina = 0;
        if (tamanho < 1 || tamanho > 100) tamanho = 20;
        PageRequest pageable = PageRequest.of(pagina, tamanho, Sort.by(Sort.Direction.DESC, "dataCriacao"));
        Page<Avaliacao> page = avaliacaoRepository.findByAutorPaginado(autor, pageable);
        List<AvaliacaoPublicaDTO> dtos = aplicarCurtidasEmLote(page.getContent());
        return new PageImpl<>(dtos, pageable, page.getTotalElements());
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
                return new PageImpl<>(Collections.emptyList(), pageRequest, 0);
            }
            return avaliacaoRepository.findFeedPaginadoDeAutores(idsAutores, pageRequest);
        }

        return avaliacaoRepository.findFeedPaginado(pageRequest);
    }

    private List<AvaliacaoPublicaDTO> aplicarCurtidasEmLote(List<Avaliacao> lista) {
        if (lista == null || lista.isEmpty()) return Collections.emptyList();
        List<Long> ids = lista.stream().map(Avaliacao::getId).collect(Collectors.toList());
        Map<Long, Long> counts = curtidaService.countsParaIds(ids);
        Set<Long> curtiIds = curtidaService.idsQueEuCurti(ids);

        return lista.stream().map(a -> {
            AvaliacaoPublicaDTO dto = AvaliacaoPublicaDTO.fromEntity(a);
            dto.setTotalCurtidas(counts.getOrDefault(a.getId(), 0L));
            dto.setCurtiEu(curtiIds.contains(a.getId()));
            return dto;
        }).collect(Collectors.toList());
    }

    public AvaliacaoPublicaDTO aplicarCurtidas(Avaliacao a) {
        AvaliacaoPublicaDTO dto = AvaliacaoPublicaDTO.fromEntity(a);
        dto.setTotalCurtidas(curtidaService.total(a));
        dto.setCurtiEu(curtidaService.curti(a));
        return dto;
    }
}
