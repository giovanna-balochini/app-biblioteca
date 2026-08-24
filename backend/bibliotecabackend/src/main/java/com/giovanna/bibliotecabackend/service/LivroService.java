package com.giovanna.bibliotecabackend.service;

import com.giovanna.bibliotecabackend.dto.LivroBuscaDTO;
import com.giovanna.bibliotecabackend.model.Livro;
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

    public Optional<Livro> buscarPorId(Long id) {
        return livroRepository.findById(id);
    }

    public Livro salvar(Livro livro) {
        if (livro.getDono() == null) {
            livro.setDono(usuarioService.obterUsuarioLogado());
        }
        return livroRepository.save(livro);
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
        copia.setLido(false);
        copia.setDono(eu);
        Livro salvo = livroRepository.save(copia);

        Map<String, Object> r = new LinkedHashMap<>();
        r.put("ok", true);
        r.put("mensagem", "Adicionado à sua biblioteca");
        r.put("livroId", salvo.getId());
        return r;
    }
}

