pub fn split_args(string: String) -> Vec<String> {
    let input_string = string;

    let mut parts_quotes: Vec<String> = Vec::new();
    let mut inside_quotes = false;
    let mut inside_single_quotes = false;
    let mut current_part = String::new();

    for char in input_string.chars() {
        match char {
            '"' => {
                if !inside_single_quotes {
                    inside_quotes = !inside_quotes;
                    if !inside_quotes {
                        parts_quotes.push(current_part.clone());
                        current_part.clear();
                    }
                } else {
                    current_part.push(char);
                }
            }
            '\'' => {
                inside_single_quotes = !inside_single_quotes;
                if !inside_single_quotes {
                    parts_quotes.push(current_part.clone());
                    current_part.clear();
                }
            }
            ' ' => {
                if !inside_quotes && !inside_single_quotes && !current_part.is_empty() {
                    parts_quotes.push(current_part.clone());
                    current_part.clear();
                } else if inside_quotes || inside_single_quotes && !current_part.is_empty() {
                    current_part.push(char);
                }
            }
            _ => {
                current_part.push(char);
            }
        }
    }

    if !current_part.is_empty() {
        parts_quotes.push(current_part);
    }

    return parts_quotes;
}
