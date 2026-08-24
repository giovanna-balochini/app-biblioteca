package com.giovanna.bibliotecabackend.service;

import com.giovanna.bibliotecabackend.model.Avaliacao;
import com.giovanna.bibliotecabackend.model.Curtida;
import com.giovanna.bibliotecabackend.model.Usuario;
import com.giovanna.bibliotecabackend.repository.AvaliacaoRepository;
import com.giovanna.bibliotecabackend.repository.CurtidaRepository;
import com.giovanna.bibliotecabackend.repository.UsuarioRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CurtidaService {
    private final CurtidaRepository curtidaRepository;
    private final AvaliacaoRepository avaliacaoRepository;
    private final UsuarioRepository usuarioRepository;
    private final NotificacaoService notificacaoService;
    private final UsuarioService usuarioService;

    public Map<String, Object> toggleCurtida(Long avaliacaoId) {
        Usuario eu = usuarioService.obterUsuarioLogado();
        Avaliacao avaliacao = avaliacaoRepository.findById(avaliacaoId)
                .orElseThrow(() -> new IllegalArgumentException("Avaliação não encontrada"));

        Optional<Curtida> existente = curtidaRepository.findByAvaliacaoAndUsuario(avaliacao, eu);

        if (existente.isPresent()) {
            curtidaRepository.deleteByAvaliacaoAndUsuario(avaliacao, eu);
            long novoTotal = curtidaRepository.countPorAvaliacao(avaliacao);
            Map<String, Object> r = new HashMap<>();
            r.put("ok", true);
            r.put("curti", false);
            r.put("totalCurtidas", novoTotal);
            r.put("acao", "descurtiu");
            return r;
        } else {
            if (eu.getId().equals(avaliacao.getAutor().getId())) {
                // ainda deixa curtir a própria? ok, mas nada impede. mas deixa.
            }
            Curtida c = new Curtida();
            c.setAvaliacao(avaliacao);
            c.setUsuario(eu);
            curtidaRepository.save(c);
            long novoTotal = curtidaRepository.countPorAvaliacao(avaliacao);

            // notifica o autor da avaliação (se não for o próprio curtindo a própria avaliação)
            if (!eu.getId().equals(avaliacao.getAutor().getId())) {
                try {
                    notificacaoService.criarNotificacaoCurtida(avaliacao.getAutor(), eu, avaliacao);
                } catch (Exception ignored) {}
            }

            Map<String, Object> r = new HashMap<>();
            r.put("ok", true);
            r.put("curti", true);
            r.put("totalCurtidas", novoTotal);
            r.put("acao", "curtiu");
            return r;
        }
    }

    public boolean curti(Avaliacao a) {
        Usuario eu = usuarioService.obterUsuarioLogadoSeAutenticado().orElse(null);
        if (eu == null) return false;
        return curtidaRepository.existsByAvaliacaoAndUsuario(a, eu);
    }

    public long total(Avaliacao a) {
        return curtidaRepository.countPorAvaliacao(a);
    }

    @Transactional(readOnly = true)
    public Map<Long, Long> countsParaIds(List<Long> idsAvaliacoes) {
        if (idsAvaliacoes == null || idsAvaliacoes.isEmpty()) return Collections.emptyMap();
        List<Object[]> rows = curtidaRepository.countsPorIdsAvaliacaoAgrupado(idsAvaliacoes);
        Map<Long, Long> mapa = new HashMap<>();
        for (Object[] r : rows) {
            Long id = (Long) r[0];
            Long count = (Long) r[1];
            mapa.put(id, count);
        }
        // zera ids que não tem nenhuma curtida
        for (Long id : idsAvaliacoes) {
            mapa.putIfAbsent(id, 0L);
        }
        return mapa;
    }

    @Transactional(readOnly = true)
    public Set<Long> idsQueEuCurti(List<Long> idsAvaliacoes) {
        Usuario eu = usuarioService.obterUsuarioLogadoSeAutenticado().orElse(null);
        if (eu == null || idsAvaliacoes == null || idsAvaliacoes.isEmpty()) return Collections.emptySet();
        return new HashSet<>(curtidaRepository.idsDasAvaliacoesQueEuCurti(eu, idsAvaliacoes));
    }
}
