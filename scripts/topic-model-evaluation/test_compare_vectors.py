import unittest

from compare_vectors import compare


class CompareVectorsTests(unittest.TestCase):
    def setUp(self):
        self.reference = {"vectors": [{"id": "a", "input_ids": [1, 2],
                                       "attention_mask": [1, 1], "vector": [1.0, 0.0]}]}

    def test_identical(self):
        self.assertEqual(compare(self.reference, {"vectors": [{"id": "a", "input_ids": [1, 2],
                                                                  "attention_mask": [1, 1], "vector": [1.0, 0.0]}]}), {"a": 1.0})

    def test_bad_tokenizer_fails(self):
        with self.assertRaisesRegex(ValueError, "Tokenizer"):
            compare(self.reference, {"vectors": [{"id": "a", "input_ids": [2, 1],
                                                  "attention_mask": [1, 1], "vector": [1.0, 0.0]}]})

    def test_bad_vector_fails(self):
        with self.assertRaisesRegex(ValueError, "Cosine"):
            compare(self.reference, {"vectors": [{"id": "a", "input_ids": [1, 2],
                                                  "attention_mask": [1, 1], "vector": [0.0, 1.0]}]})


if __name__ == "__main__":
    unittest.main()
