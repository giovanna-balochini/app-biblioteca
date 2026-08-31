package com.giovanna.bibliotecabackend.service;

import com.giovanna.bibliotecabackend.dto.RecomendacaoResponseDTO;
import com.giovanna.bibliotecabackend.model.Avaliacao;
import com.giovanna.bibliotecabackend.model.Livro;
import com.giovanna.bibliotecabackend.model.StatusLeitura;
import com.giovanna.bibliotecabackend.model.Usuario;
import com.giovanna.bibliotecabackend.repository.AvaliacaoRepository;
import com.giovanna.bibliotecabackend.repository.LivroRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class RecomendacaoService {

    private final LivroRepository livroRepository;
    private final AvaliacaoRepository avaliacaoRepository;

    private record ChaveLivroUnico(String tituloLower, String autorLower) {}

    private static class Candidato {
        Livro melhorExemplar;
        double scoreBrutoGenero = 0d;
        double scoreBrutoAutor = 0d;
        double notaMedia = 0d;
        long qtdeAvaliacoes = 0L;
        final List<String> motivos = new ArrayList<>();
    }

    public List<RecomendacaoResponseDTO> gerarRecomendacoesPara(Usuario eu) {
        List<Livro> livrosPositivos = buscarLivrosPositivosDoUsuario(eu);
        if (livrosPositivos.isEmpty()) {
            return gerarRecomendacoesGerais(eu, 10);
        }

        Map<String, Long> freqGeneros = new HashMap<>();
        Map<String, Long> freqAutores = new HashMap<>();

        for (Livro l : livrosPositivos) {
            if (l.getGenero() != null && !l.getGenero().isBlank()) {
                String g = l.getGenero().trim().toLowerCase();
                freqGeneros.merge(g, 1L, Long::sum);
            }
            if (l.getAutor() != null && !l.getAutor().isBlank()) {
                String a = l.getAutor().trim().toLowerCase();
                freqAutores.merge(a, 1L, Long::sum);
            }
        }

        long maxFreqG = freqGeneros.values().stream().max(Long::compareTo).orElse(1L);
        long maxFreqA = freqAutores.values().stream().max(Long::compareTo).orElse(1L);

        List<Livro> todosLivrosOutros = livroRepository.findAll().stream()
                .filter(l -> !eu.getId().equals(l.getDono() == null ? null : l.getDono().getId()))
                .toList();

        Map<ChaveLivroUnico, Candidato> unicos = new LinkedHashMap<>();
        for (Livro l : todosLivrosOutros) {
            if (l.getTitulo() == null || l.getAutor() == null) continue;
            ChaveLivroUnico chave = new ChaveLivroUnico(
                    l.getTitulo().trim().toLowerCase(),
                    l.getAutor().trim().toLowerCase()
            );
            if (livroRepository.existeNaBibliotecaDe(eu, l.getTitulo(), l.getAutor())) continue;
            unicos.computeIfAbsent(chave, k -> new Candidato());
            Candidato c = unicos.get(chave);
            if (c.melhorExemplar == null ||
                    (c.melhorExemplar.getImagem() == null && l.getImagem() != null) ||
                    (l.getImagem() != null && c.melhorExemplar.getImagem() == null)) {
                c.melhorExemplar = l;
            }
        }

        for (Candidato c : unicos.values()) {
            Livro l = c.melhorExemplar;
            String genero = l.getGenero() == null ? null : l.getGenero().trim().toLowerCase();
            String autor = l.getAutor() == null ? null : l.getAutor().trim().toLowerCase();

            if (genero != null && freqGeneros.containsKey(genero)) {
                long freqG = freqGeneros.get(genero);
                c.scoreBrutoGenero = ((double) freqG / maxFreqG) * 60.0;
                c.motivos.add(
                        "Gênero " + capitalizar(l.getGenero()) + " (você leu " + freqG +
                                (freqG == 1 ? " livro" : " livros") + " desse gênero)"
                );
            }

            if (autor != null && freqAutores.containsKey(autor)) {
                long freqA = freqAutores.get(autor);
                c.scoreBrutoAutor = ((double) freqA / maxFreqA) * 40.0;
                c.motivos.add(
                        "Mesmo autor(a) " + capitalizar(l.getAutor()) +
                                " (" + freqA + (freqA == 1 ? " livro lido" : " livros lidos") + ")"
                );
            }

            Double media = avaliacaoRepository.calcularMediaPorLivro(l);
            long qtde = avaliacaoRepository.countByLivro(l);
            c.notaMedia = media == null ? 0d : media;
            c.qtdeAvaliacoes = qtde;
        }

        return unicos.values().stream()
                .sorted(Comparator.comparingDouble((Candidato c) -> {
                    double base = c.scoreBrutoGenero + c.scoreBrutoAutor;
                    if (c.notaMedia >= 4.0d && c.qtdeAvaliacoes >= 1L) {
                        base = Math.min(100.0d, base + 8.0d);
                        c.motivos.add("Avaliado com nota média " + String.format("%.1f", c.notaMedia) + " ★ pela comunidade");
                    }
                    return base;
                }).reversed())
                .limit(12)
                .map(c -> {
                    Livro l = c.melhorExemplar;
                    double matchPct = Math.min(100.0d, Math.max(5.0d,
                            Math.round((c.scoreBrutoGenero + c.scoreBrutoAutor + (c.notaMedia >= 4 ? 8 : 0)) * 10.0) / 10.0));
                    return RecomendacaoResponseDTO.builder()
                            .livroId(l.getId())
                            .idProprietarioOriginal(l.getDono() == null ? null : l.getDono().getId())
                            .titulo(l.getTitulo())
                            .autor(l.getAutor())
                            .genero(l.getGenero())
                            .editora(l.getEditora())
                            .imagem(l.getImagem())
                            .descricao(l.getDescricao())
                            .matchPercentual((int) Math.round(matchPct))
                            .motivos(new ArrayList<>(c.motivos))
                            .notaMedia(c.notaMedia == 0d ? null : c.notaMedia)
                            .quantidadeAvaliacoes(c.qtdeAvaliacoes)
                            .build();
                })
                .collect(Collectors.toList());
    }

    private List<RecomendacaoResponseDTO> gerarRecomendacoesGerais(Usuario eu, int limite) {
        List<Livro> todosOutros = livroRepository.findAll().stream()
                .filter(l -> !eu.getId().equals(l.getDono() == null ? null : l.getDono().getId()))
                .filter(l -> l.getTitulo() != null && l.getAutor() != null)
                .filter(l -> !livroRepository.existeNaBibliotecaDe(eu, l.getTitulo(), l.getAutor()))
                .toList();

        Map<ChaveLivroUnico, Candidato> unicos = new LinkedHashMap<>();
        for (Livro l : todosOutros) {
            ChaveLivroUnico chave = new ChaveLivroUnico(
                    l.getTitulo().trim().toLowerCase(),
                    l.getAutor().trim().toLowerCase()
            );
            unicos.computeIfAbsent(chave, k -> new Candidato());
            Candidato c = unicos.get(chave);
            if (c.melhorExemplar == null || (c.melhorExemplar.getImagem() == null && l.getImagem() != null)) {
                c.melhorExemplar = l;
            }
        }

        for (Candidato c : unicos.values()) {
            Livro l = c.melhorExemplar;
            Double media = avaliacaoRepository.calcularMediaPorLivro(l);
            long qtde = avaliacaoRepository.countByLivro(l);
            c.notaMedia = media == null ? 0d : media;
            c.qtdeAvaliacoes = qtde;
            if (qtde > 0) {
                c.motivos.add("Populares da comunidade (" + qtde +
                        (qtde == 1 ? " avaliação" : " avaliações") + ")");
            } else {
                c.motivos.add("Descubra novas leituras");
            }
        }

        return unicos.values().stream()
                .sorted(Comparator.comparingDouble((Candidato c) -> c.qtdeAvaliacoes * 100d + c.notaMedia * 10d).reversed())
                .limit(limite)
                .map(c -> {
                    Livro l = c.melhorExemplar;
                    return RecomendacaoResponseDTO.builder()
                            .livroId(l.getId())
                            .idProprietarioOriginal(l.getDono() == null ? null : l.getDono().getId())
                            .titulo(l.getTitulo())
                            .autor(l.getAutor())
                            .genero(l.getGenero())
                            .editora(l.getEditora())
                            .imagem(l.getImagem())
                            .descricao(l.getDescricao())
                            .matchPercentual((int) Math.min(100d, Math.max(30d,
                                    Math.round(30d + Math.min(60d, c.qtdeAvaliacoes * 10d) + Math.min(10d, c.notaMedia * 2d)))))
                            .motivos(new ArrayList<>(c.motivos))
                            .notaMedia(c.notaMedia == 0d ? null : c.notaMedia)
                            .quantidadeAvaliacoes(c.qtdeAvaliacoes)
                            .build();
                })
                .collect(Collectors.toList());
    }

    private List<Livro> buscarLivrosPositivosDoUsuario(Usuario eu) {
        List<Livro> livrosUsuario = livroRepository.findByDono(eu);
        Set<Long> idsLivrosBons = new HashSet<>();

        for (Livro l : livrosUsuario) {
            if (StatusLeitura.LIDO.equals(l.getStatusLeitura())) {
                idsLivrosBons.add(l.getId());
                continue;
            }
            Optional<Avaliacao> av = avaliacaoRepository.findByAutorAndLivro(eu, l);
            if (av.isPresent() && av.get().getNota() != null && av.get().getNota() >= 4) {
                idsLivrosBons.add(l.getId());
            }
        }

        return livrosUsuario.stream()
                .filter(l -> idsLivrosBons.contains(l.getId()))
                .collect(Collectors.toList());
    }

    private static String capitalizar(String s) {
        if (s == null || s.isBlank()) return s;
        String[] palavras = s.trim().split("\\s+");
        List<String> out = new ArrayList<>();
        for (String p : palavras) {
            if (p.length() <= 1) out.add(p.toUpperCase());
            else out.add(Character.toUpperCase(p.charAt(0)) + p.substring(1).toLowerCase());
        }
        return String.join(" ", out);
    }
}
