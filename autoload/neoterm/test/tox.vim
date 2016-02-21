if has('python3')
    command! -nargs=1 AvailablePython python3 <args>
else
    throw 'No python3 support present, tox test lib will be disabled'
endif


function! neoterm#test#tox#run(scope) abort
    if exists('g:neoterm_tox_lib_args')
        let l:command = 'tox ' . g:neoterm_tox_lib_args
    else
        let l:command = 'tox'
    end

    if exists('g:neoterm_tox_lib_testargs')
        let l:command .= ' -- ' . g:neoterm_tox_lib_testargs
    else
        let l:command .= ' --'
    end

    if a:scope ==# 'file'
        let l:command .= ' ' . expand('%:p')
    elseif a:scope ==# 'current'
        let l:path = expand('%:p')
        let l:linenum = line('.')
        let l:cmd = "NearestDef.name"
        let l:funcname = py3eval(l:cmd . "('". l:path . "', ". l:linenum . ")")
        echo l:funcname
        let l:command .= ' -k ' . l:funcname . ' ' . l:path
    endif

    return l:command
endfunction



AvailablePython <<EOF
import ast
from collections import defaultdict

class NearestDef:

    @classmethod
    def process_line(cls, node, col_offset, found):
        node_lineno = node.lineno
        if node.col_offset == 0:
            return None
        valid_offsets = [o for o in sorted(col_offset)
                         if o < node.col_offset]
        offset = valid_offsets[-1]
        valid_nodes = [n for n in found[offset]
                       if n.lineno < node_lineno]
        return valid_nodes[-1]


    @classmethod
    def name(cls, path, linenum):
        """Nearest function name"""
        with open(path) as fileobj:
            source = fileobj.read()
        root = ast.parse(source)
        col_offset = []
        found = defaultdict(list)
        line_firstnode = {}
        for node in ast.walk(root):
            node_lineno = getattr(node, 'lineno', None)
            node_col_offset = getattr(node, 'col_offset', None)
            if node_lineno and node_lineno not in line_firstnode:
                line_firstnode[node_lineno] = node

            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef,
                                 ast.ClassDef, ast.Module)):
                found[node_col_offset].append(node)
                if node != root and node_col_offset not in col_offset:
                    col_offset.append(node_col_offset)

            if node_lineno == linenum:
                retnode = cls.process_line(node, col_offset, found)
                return '' if retnode is None else retnode.name

        # Didn't find anything (line is a comment or blank line)
        line_nodes = sorted(line_firstnode.items(), key=lambda k: k[0])
        line_nodes = [n[1] for n in line_nodes if n[0] < linenum]
        retnode = cls.process_line(line_nodes[-1], col_offset, found)
        return '' if retnode is None else retnode.name

EOF
