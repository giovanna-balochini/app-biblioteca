package com.giovanna.bibliotecabackend.service;

import com.giovanna.bibliotecabackend.model.Livro;
import com.giovanna.bibliotecabackend.model.Usuario;
import com.giovanna.bibliotecabackend.repository.LivroRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class LivroService {

    private final LivroRepository livroRepository;
    private final UsuarioService usuarioService;

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
}
