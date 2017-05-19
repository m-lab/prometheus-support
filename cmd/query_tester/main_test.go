// query_tester evaluates all query tests found in testdata/*.txt files.
//
// We implement query_tester as a Go test because promql.NewTest requires a
// testing.T instance.
package main_test

import (
	"io/ioutil"
	"path/filepath"
	"testing"

	"github.com/prometheus/prometheus/promql"
)

func TestEvaluations(t *testing.T) {
	files, err := filepath.Glob("testdata/*.txt")
	if err != nil {
		t.Fatal(err)
	}
	for _, file := range files {
		t.Logf("Running %s", file)
		content, err := ioutil.ReadFile(file)
		if err != nil {
			t.Error(err)
			continue
		}
		test, err := promql.NewTest(t, string(content))
		if err != nil {
			t.Errorf("Failed to create test for %s: %s", file, err)
		}
		err = test.Run()
		if err != nil {
			t.Errorf("Failed to run test %s: %s", file, err)
		}
		test.Close()
	}
}
