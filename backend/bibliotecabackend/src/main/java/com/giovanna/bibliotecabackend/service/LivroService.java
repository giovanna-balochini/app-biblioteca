package com.giovanna.bibliotecabackend.service;

import com.giovanna.bibliotecabackend.dto.LivroBuscaDTO;
import com.giovanna.bibliotecabackend.model.Livro;
import com.giovanna.bibliotecabackend.model.StatusLeitura;
import com.giovanna.bibliotecabackend.model.Usuario;
import com.giovanna.bibliotecabackend.repository.AvaliacaoRepository;
import com.giovanna.bibliotecabackend.repository.LivroRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class LivroService {

    private final LivroRepository livroRepository;
    private final UsuarioService usuarioService;
    private final AvaliacaoRepository avaliacaoRepository;

    public List<Livro> listarTodos() {
        Usuario dono = usuarioService.obterUsuarioLogado();
        return livroRepository.findByDono(dono);
    }

    public List<Livro> listarPorStatus(StatusLeitura status) {
        Usuario dono = usuarioService.obterUsuarioLogado();
        return livroRepository.findByDonoAndStatusLeitura(dono, status);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> resumoEstante() {
        Usuario eu = usuarioService.obterUsuarioLogado();
        Map<String, Object> resumo = new LinkedHashMap<>();
        long total = livroRepository.countByDono(eu);
        long queroLer = livroRepository.countByDonoAndStatusLeitura(eu, StatusLeitura.QUERO_LER);
        long lendo = livroRepository.countByDonoAndStatusLeitura(eu, StatusLeitura.LENDO);
        long lidos = livroRepository.countByDonoAndStatusLeitura(eu, StatusLeitura.LIDO);
        Long pagsLidas = livroRepository.somarPaginasLidasAtualmente(eu);
        Long pagsTotais = livroRepository.somarTotalPaginasAtualmente(eu);
        double progressoGeralLendo = 0.0;
        if (pagsTotais != null && pagsTotais > 0 && pagsLidas != null) {
            progressoGeralLendo = Math.round((pagsLidas * 100.0 / pagsTotais) * 10.0) / 10.0;
            if (progressoGeralLendo > 100) progressoGeralLendo = 100;
        }
        resumo.put("total", total);
        resumo.put("queroLer", queroLer);
        resumo.put("lendo", lendo);
        resumo.put("lidos", lidos);
        resumo.put("paginasLidasEmAndamento", pagsLidas == null ? 0L : pagsLidas);
        resumo.put("totalPaginasEmAndamento", pagsTotais == null ? 0L : pagsTotais);
        resumo.put("progressoGeralLendo", progressoGeralLendo);
        return resumo;
    }

    public Optional<Livro> buscarPorId(Long id) {
        return livroRepository.findById(id);
    }

    public Livro salvar(Livro livro) {
        if (livro.getDono() == null) {
            livro.setDono(usuarioService.obterUsuarioLogado());
        }
        return livroRepository.save(livro);
    }

    @Transactional
    public Optional<Livro> atualizarProgresso(Long id, Integer paginaAtual, Integer totalPaginas) {
        Optional<Livro> opt = livroRepository.findById(id);
        if (opt.isEmpty()) return Optional.empty();
        Livro l = opt.get();
        Usuario eu = usuarioService.obterUsuarioLogado();
        if (l.getDono() == null || eu.getId() == null || !eu.getId().equals(l.getDono().getId())) {
            return Optional.empty();
        }
        if (totalPaginas != null) l.setTotalPaginas(totalPaginas);
        if (paginaAtual != null) l.setPaginaAtual(paginaAtual);
        if (l.getPaginaAtual() != null && l.getPaginaAtual() > 0
                && (l.getStatusLeitura() == null || StatusLeitura.QUERO_LER.equals(l.getStatusLeitura()))) {
            l.setStatusLeitura(StatusLeitura.LENDO);
            if (l.getDataInicioLeitura() == null) l.setDataInicioLeitura(LocalDate.now());
        }
        if (l.getTotalPaginas() != null && l.getTotalPaginas() > 0
                && l.getPaginaAtual() != null && l.getPaginaAtual() >= l.getTotalPaginas()) {
            marcarComoConcluido(l);
        }
        return Optional.of(livroRepository.save(l));
    }

    @Transactional
    public Optional<Livro> alterarStatus(Long id, StatusLeitura novoStatus) {
        Optional<Livro> opt = livroRepository.findById(id);
        if (opt.isEmpty()) return Optional.empty();
        Livro l = opt.get();
        Usuario eu = usuarioService.obterUsuarioLogado();
        if (l.getDono() == null || eu.getId() == null || !eu.getId().equals(l.getDono().getId())) {
            return Optional.empty();
        }
        l.setStatusLeitura(novoStatus);
        if (StatusLeitura.LENDO.equals(novoStatus) && l.getDataInicioLeitura() == null) {
            l.setDataInicioLeitura(LocalDate.now());
        }
        if (StatusLeitura.LIDO.equals(novoStatus)) {
            marcarComoConcluido(l);
        }
        if (StatusLeitura.QUERO_LER.equals(novoStatus)) {
            l.setPaginaAtual(0);
            l.setDataInicioLeitura(null);
            l.setDataFimLeitura(null);
        }
        return Optional.of(livroRepository.save(l));
    }

    private void marcarComoConcluido(Livro l) {
        l.setStatusLeitura(StatusLeitura.LIDO);
        if (l.getTotalPaginas() != null && l.getTotalPaginas() > 0) {
            l.setPaginaAtual(l.getTotalPaginas());
        }
        if (l.getDataInicioLeitura() == null) l.setDataInicioLeitura(LocalDate.now());
        if (l.getDataFimLeitura() == null) l.setDataFimLeitura(LocalDate.now());
    }

    public void deletar(Long id) {
        livroRepository.deleteById(id);
    }

    @Transactional(readOnly = true)
    public Page<LivroBuscaDTO> buscarLivros(String q, int pagina, int tamanho) {
        if (q == null || q.trim().isEmpty()) {
            q = "";
        }
        if (pagina < 0) pagina = 0;
        if (tamanho < 1 || tamanho > 50) tamanho = 20;
        Pageable pageable = PageRequest.of(pagina, tamanho, Sort.by(Sort.Direction.DESC, "id"));
        Page<Livro> paginaLivros = livroRepository.buscarPorTituloAutorGenero(q.trim(), pageable);

        Optional<Usuario> euOpt = usuarioService.obterUsuarioLogadoSeAutenticado();
        Usuario eu = euOpt.orElse(null);

        return paginaLivros.map(l -> {
            long totalAvaliacoes = avaliacaoRepository.countByLivro(l);
            Double media = avaliacaoRepository.calcularMediaPorLivro(l);
            boolean meu = eu != null && l.getDono() != null && eu.getId() != null
                    && eu.getId().equals(l.getDono().getId());
            boolean jaTenho = meu || (eu != null
                    && livroRepository.existeNaBibliotecaDe(eu,
                            l.getTitulo() == null ? "" : l.getTitulo(),
                            l.getAutor() == null ? "" : l.getAutor()));
            return LivroBuscaDTO.fromEntity(l, totalAvaliacoes, media, jaTenho);
        });
    }

    @Transactional
    public Map<String, Object> copiarParaMinhaBiblioteca(Long idLivroOrigem) {
        Usuario eu = usuarioService.obterUsuarioLogado();
        Livro origem = livroRepository.findById(idLivroOrigem)
                .orElseThrow(() -> new IllegalArgumentException("Livro não encontrado"));

        if (origem.getDono() != null && origem.getDono().getId() != null
                && origem.getDono().getId().equals(eu.getId())) {
            Map<String, Object> r = new LinkedHashMap<>();
            r.put("ok", false);
            r.put("motivo", "ESSE_EH_SEU");
            r.put("mensagem", "Esse livro já é da sua biblioteca");
            r.put("livroId", origem.getId());
            return r;
        }

        String titulo = origem.getTitulo() == null ? "" : origem.getTitulo();
        String autor = origem.getAutor() == null ? "" : origem.getAutor();
        if (livroRepository.existeNaBibliotecaDe(eu, titulo, autor)) {
            Optional<Livro> jaExiste = livroRepository.findByDono(eu).stream()
                    .filter(meu -> titulo.equalsIgnoreCase(meu.getTitulo() == null ? "" : meu.getTitulo())
                            && autor.equalsIgnoreCase(meu.getAutor() == null ? "" : meu.getAutor()))
                    .findFirst();
            Map<String, Object> r = new LinkedHashMap<>();
            r.put("ok", false);
            r.put("motivo", "JA_TEM_NA_BIBLIOTECA");
            r.put("mensagem", "Você já tem esse livro na sua biblioteca");
            r.put("livroId", jaExiste.map(Livro::getId).orElse(null));
            return r;
        }

        Livro copia = new Livro();
        copia.setTitulo(titulo);
        copia.setAutor(autor);
        copia.setEditora(origem.getEditora());
        copia.setGenero(origem.getGenero());
        copia.setDescricao(origem.getDescricao());
        copia.setImagem(origem.getImagem());
        copia.setStatusLeitura(StatusLeitura.QUERO_LER);
        copia.setTotalPaginas(origem.getTotalPaginas());
        copia.setDono(eu);
        Livro salvo = livroRepository.save(copia);

        Map<String, Object> r = new LinkedHashMap<>();
        r.put("ok", true);
        r.put("mensagem", "Adicionado à sua biblioteca");
        r.put("livroId", salvo.getId());
        return r;
    }
}
