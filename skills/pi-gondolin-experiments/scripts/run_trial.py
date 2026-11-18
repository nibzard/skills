"""Run one trial from a saved input directory and preserve its evidence."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import time


def execute(command, directory, output, name, timeout):
    start = time.monotonic()
    with (output / (name + '.stdout')).open('w') as stdout:
        with (output / (name + '.stderr')).open('w') as stderr:
            process = subprocess.Popen(command, cwd=directory, stdout=stdout,
                                       stderr=stderr, start_new_session=True)
            timed_out = False
            try:
                code = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                timed_out = True
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                code = process.returncode
    return {'exit_code': code, 'timed_out': timed_out,
            'seconds': round(time.monotonic() - start, 3)}


def expand(command, values):
    result = []
    for argument in command:
        for key, value in values.items():
            argument = argument.replace('{' + key + '}', str(value))
        result.append(argument)
    return result


def run(config_path, output):
    config_path = config_path.resolve()
    config = json.loads(config_path.read_text())
    source = Path(config['source']).expanduser().resolve()
    output = output.resolve()
    if not source.is_dir():
        raise ValueError('Source must be an existing directory')
    if output == source or source in output.parents:
        raise ValueError('Save trial output outside its source directory')
    if any(path.is_symlink() for path in source.rglob('*')):
        raise ValueError('Use a source snapshot with regular files and directories')
    for key in ('agent_command', 'evaluate_command'):
        if not isinstance(config.get(key), list) or not config[key] or not all(isinstance(x, str) for x in config[key]):
            raise ValueError(key + ' must be a nonempty argument list')
    timeout = config.get('timeout_seconds', 240)
    if not isinstance(timeout, int) or timeout <= 0:
        raise ValueError('timeout_seconds must be a positive integer')
    output.mkdir(parents=True, exist_ok=False)
    project = output / 'project'
    shutil.copytree(source, project)
    manifest = {
        'config': config,
        'runner_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'input_sha256': {
            str(path.relative_to(source)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(source.rglob('*')) if path.is_file()
        },
    }
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (output / 'prompt.txt').write_text(config['prompt'])
    values = {'project': project, 'output': output, 'prompt': config['prompt']}
    result = {'status': 'infrastructure_failure'}
    try:
        agent = execute(expand(config['agent_command'], values), project,
                        output, 'agent', timeout)
        result['agent'] = agent
        if agent['timed_out']:
            result['status'] = 'timeout'
        elif agent['exit_code'] != 0:
            result['status'] = 'agent_failure'
        else:
            evaluation = execute(expand(config['evaluate_command'], values),
                                 config_path.parent, output, 'evaluation', timeout)
            result['evaluation'] = evaluation
            if evaluation['exit_code'] == 0 and not evaluation['timed_out']:
                measured = json.loads((output / 'evaluation.stdout').read_text())
                if not isinstance(measured, dict) or not isinstance(measured.get('valid'), bool):
                    raise ValueError('Evaluator must return a boolean valid field')
                result['measurement'] = measured
                result['status'] = 'valid' if measured['valid'] else 'invalid_candidate'
    except (OSError, ValueError) as error:
        result['error'] = str(error)
    finally:
        (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))
    return 0 if result['status'] == 'valid' else 1


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('config', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    raise SystemExit(run(args.config, args.output))
