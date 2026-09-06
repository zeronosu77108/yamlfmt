# yamlfmt

`yamlfmt` is a comment-preserving, minimal-diff YAML formatter for Ruby. It
applies targeted edits to the original source instead of re-emitting the entire
document, preserving comments and untouched formatting.

It is built on [psych-pure](https://github.com/kddnewton/psych-pure).

This project is unrelated to the Go formatter with the same name.

## Installation

Install yamlfmt from RubyGems:

```console
$ gem install yamlfmt
```

To use it in a Rails application, add it to the application's `Gemfile`:

```ruby
group :development, :test do
  gem "yamlfmt", require: false
end
```

Then run `bundle install` and invoke it with `bundle exec yamlfmt`.

yamlfmt requires Ruby 3.3 or newer.

## Usage

Running without an option checks YAML files below the current directory. It
reports formatting issues but never modifies a file.

```console
$ yamlfmt
$ yamlfmt config/locales
$ yamlfmt config/application.yml
```

Directories are searched recursively for `.yml` and `.yaml` files. A file
passed directly is checked regardless of its extension. Hidden directories,
including `.github`, are searched; `.git` and symbolic links are always
skipped.

Preview a unified diff before applying changes:

```console
$ yamlfmt --diff
$ yamlfmt --fix
```

`--fix` with no path rewrites every applicable YAML file below the current
directory. Running `--diff` first is strongly recommended. `--fix` and
`--diff` cannot be combined.

Create a starter configuration:

```console
$ yamlfmt --init
```

Other options are available through `yamlfmt --help`. Colors are used only when
writing a diff to a terminal and can be disabled with `--no-color`.

Check mode ends with the number of files inspected, issues found, and issues
that can be corrected automatically:

```text
12 files inspected, 5 issues found, 4 autocorrectable
```

Fix mode instead reports how many issues and files were actually corrected,
followed by the number of issues that remain when applicable:

```text
12 files inspected, 5 issues found, 4 corrected in 2 files, 1 issue remains
```

Warnings and failed files are reported separately from issue counts. Diff mode
does not print a summary, so its output can be redirected or piped as a patch.

### Exit status

| Status | Meaning |
|---|---|
| 0 | No issues, no targets, or all requested fixes succeeded |
| 1 | Formatting issues in check/diff mode, invalid input, an unsupported file, or a failed fix |

When one file fails, yamlfmt continues processing the remaining files. In fix
mode, files that pass validation are still rewritten, and the final status is
1 if any file failed.

## Configuration

yamlfmt reads `.yamlfmt.yml` from the current directory only. It does not search
parent directories.

```yaml
rules:
  trailing-whitespace: true
  final-newline: true
  blank-lines:
    max: 1
  unnecessary-quotes: true

exclude:
  - vendor
  - node_modules
  - "*.generated.yml"
  - "tmp/**"
```

Set a rule to `false` to disable it. A mapping overrides that rule's options.
Unknown rule and option names produce warnings; invalid values are errors.

Exclude patterns are relative to the current directory:

- A name without `/`, such as `node_modules`, matches a file or directory with
  that name at any depth. Matching a directory excludes everything below it.
- A path such as `config/generated` matches that path and everything below it.
- `*` matches characters within one path component, `?` matches one character,
  and a final `/**` matches everything below a directory.
- Gitignore-style negation with `!` is not supported.

Quote patterns beginning with `*` in YAML so they are not interpreted as YAML
aliases. Exclusions also apply to files passed explicitly.

yamlfmt does not read `.gitignore`. Configure exclusions in `.yamlfmt.yml`.

## Rules

### `trailing-whitespace`

Removes spaces and tabs at line endings.

### `final-newline`

Adds a missing final newline and removes extra blank lines at the end of a
file. Existing LF or CRLF line endings are preserved.

### `blank-lines`

Limits consecutive blank lines within a file. Whitespace-only lines count as
blank. The default maximum is one.

### `unnecessary-quotes`

Removes single or double quotes only when Psych would emit the string in plain
style. Values such as `yes`, numbers, dates, `null`, interpolation placeholders,
and strings with YAML indicators remain quoted. Both YAML values and keys are
checked.

For example, only the safely unquotable value is changed:

```diff
-foo: "hello"
+foo: hello
 bar: "yes"
 date: "2026-09-06"
```

## Safety and known limitations

Before a changed file is written, yamlfmt checks that:

- `Psych.safe_load_stream` produces an equivalent Ruby value;
- the number and logical content of comments are unchanged; and
- the corrected source can still be parsed as supported YAML.

The file is not written if validation fails.

yamlfmt skips line-based rules for an entire file when it contains a block
scalar (`|` or `>`). `unnecessary-quotes` still runs. This restriction avoids a
known psych-pure location bug; yamlfmt prints a warning when it applies.

The following inputs are currently unsupported and cause exit status 1 without
modifying that file:

- multiple YAML documents;
- a UTF-8 byte order mark;
- custom YAML tags; and
- anchors attached directly to scalar values.

## Development

After checking out the repository, install the selected Ruby and dependencies:

```console
$ rbenv install --skip-existing 3.3.5
$ bundle install
```

Run the tests and Standard Ruby checks together:

```console
$ bundle exec rake
```

Build the gem with `bundle exec rake build` or install it locally with
`bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on
[GitHub](https://github.com/zeronosu77108/yamlfmt).
